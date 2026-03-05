use std::error::Error;

use axum::{
    Json,
    body::Body,
    extract::{Path, State},
    http::{Request, StatusCode},
};
use entity::{
    guild, hunter,
    quest::{self, QuestStatCategory, QuestStatus},
    user,
};
use migration::MigratorTrait;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ConnectionTrait, Database, DatabaseBackend, EntityTrait,
    Statement,
};
use tower::ServiceExt;
use uuid::Uuid;

use crate::{
    app::build_router,
    error::AppError,
    extractors::{GuildMasterClaims, HunterClaims},
    jwt::{AuthRole, Claims, GuildRole, JwtService},
    state::AppState,
};

use super::{CreateQuestRequest, ReviewQuestRequest, create_quest, review_quest};

#[tokio::test]
async fn member_token_cannot_create_quest() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, _master_claims, hunter_claims) = ctx.seed_guild("a").await?;
    let token = state
        .jwt
        .issue_player_token(
            hunter_claims.0.sub,
            hunter_claims.0.guild_id,
            GuildRole::Member,
        )?
        .access_token;

    let app = build_router(state, "*", true)?;
    let request = Request::builder()
            .method("POST")
            .uri("/api/v1/quests")
            .header("content-type", "application/json")
            .header("authorization", format!("Bearer {token}"))
            .body(Body::from(
                r#"{"title":"Math","description":"Do worksheet","reward_xp":20,"reward_coins":5,"stat_category":"AGI"}"#,
            ))?;

    let response = app.oneshot(request).await?;
    assert_eq!(response.status(), StatusCode::FORBIDDEN);

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn guild_cannot_review_other_guild_quest() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, _master_a, _hunter_a) = ctx.seed_guild("a").await?;
    let (_state_ignored, master_b, _hunter_b) = ctx.seed_guild("b").await?;

    let quest_a = quest::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(Uuid::parse_str("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")?),
        title: Set("Quest A".to_string()),
        description: Set(Some("A".to_string())),
        reward_xp: Set(20),
        reward_coins: Set(10),
        stat_category: Set(QuestStatCategory::Str),
        status: Set(QuestStatus::PendingReview),
    }
    .insert(&state.db)
    .await?;

    let err = review_quest(
        master_b,
        State(state),
        Path(quest_a.id),
        Json(ReviewQuestRequest {
            approved: false,
            hunter_id: None,
        }),
    )
    .await
    .expect_err("cross-guild review should fail");

    assert!(matches!(err, AppError::NotFound(_)));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn review_rollback_keeps_quest_pending_when_reward_overflows() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, master_claims, hunter_claims) = ctx.seed_guild("overflow").await?;

    let quest = quest::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(master_claims.0.guild_id),
        title: Set("Overflow Quest".to_string()),
        description: Set(None),
        reward_xp: Set(1),
        reward_coins: Set(1),
        stat_category: Set(QuestStatCategory::Vit),
        status: Set(QuestStatus::PendingReview),
    }
    .insert(&state.db)
    .await?;

    let mut hunter_model = hunter::Entity::find_by_id(hunter_claims.0.sub)
        .one(&state.db)
        .await?
        .expect("hunter should exist");
    let mut hunter_am: hunter::ActiveModel = hunter_model.clone().into();
    hunter_am.xp = Set(i32::MAX);
    hunter_am.coins = Set(0);
    hunter_model = hunter_am.update(&state.db).await?;

    let err = review_quest(
        master_claims,
        State(state.clone()),
        Path(quest.id),
        Json(ReviewQuestRequest {
            approved: true,
            hunter_id: Some(hunter_model.id),
        }),
    )
    .await
    .expect_err("overflow should fail and rollback");
    assert!(matches!(err, AppError::BadRequest(_)));

    let quest_after = quest::Entity::find_by_id(quest.id)
        .one(&state.db)
        .await?
        .expect("quest should exist");
    assert_eq!(quest_after.status, QuestStatus::PendingReview);

    let hunter_after = hunter::Entity::find_by_id(hunter_model.id)
        .one(&state.db)
        .await?
        .expect("hunter should exist");
    assert_eq!(hunter_after.xp, i32::MAX);
    assert_eq!(hunter_after.coins, 0);

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn create_submit_review_happy_path() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, master_claims, hunter_claims) = ctx.seed_guild("happy").await?;

    let (_, created) = create_quest(
        master_claims.clone(),
        State(state.clone()),
        Json(CreateQuestRequest {
            title: "Read".to_string(),
            description: Some("Read 20 mins".to_string()),
            reward_xp: 10,
            reward_coins: 3,
            stat_category: QuestStatCategory::Int,
        }),
    )
    .await?;
    assert_eq!(created.stat_category, QuestStatCategory::Int);

    let submitted = super::submit_quest(
        hunter_claims.clone(),
        State(state.clone()),
        Path(created.id),
    )
    .await?;
    assert_eq!(submitted.status, QuestStatus::PendingReview);

    let reviewed = review_quest(
        master_claims,
        State(state.clone()),
        Path(created.id),
        Json(ReviewQuestRequest {
            approved: true,
            hunter_id: Some(hunter_claims.0.sub),
        }),
    )
    .await?;
    assert_eq!(reviewed.quest.status, QuestStatus::Completed);
    assert!(reviewed.hunter.is_some());
    assert!(reviewed.reward.is_some());
    assert_eq!(reviewed.hunter.as_ref().map(|h| h.xp), Some(10));
    assert_eq!(reviewed.hunter.as_ref().map(|h| h.coins), Some(3));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.gained_xp), Some(10));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.gained_coins), Some(3));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.leveled_up), Some(false));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.new_level), Some(1));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn review_returns_level_up_event_when_xp_crosses_threshold() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, master_claims, hunter_claims) = ctx.seed_guild("lvlup").await?;

    let quest = quest::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(master_claims.0.guild_id),
        title: Set("Level Up Quest".to_string()),
        description: Set(Some("Cross XP threshold".to_string())),
        reward_xp: Set(10),
        reward_coins: Set(5),
        stat_category: Set(QuestStatCategory::Int),
        status: Set(QuestStatus::PendingReview),
    }
    .insert(&state.db)
    .await?;

    let mut hunter_model = hunter::Entity::find_by_id(hunter_claims.0.sub)
        .one(&state.db)
        .await?
        .expect("hunter should exist");
    let mut hunter_am: hunter::ActiveModel = hunter_model.clone().into();
    hunter_am.xp = Set(95);
    hunter_am.level = Set(1);
    hunter_model = hunter_am.update(&state.db).await?;

    let reviewed = review_quest(
        master_claims,
        State(state.clone()),
        Path(quest.id),
        Json(ReviewQuestRequest {
            approved: true,
            hunter_id: Some(hunter_model.id),
        }),
    )
    .await?;

    assert_eq!(reviewed.quest.status, QuestStatus::Completed);
    assert_eq!(reviewed.hunter.as_ref().map(|h| h.level), Some(2));
    assert_eq!(reviewed.hunter.as_ref().map(|h| h.xp), Some(105));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.gained_xp), Some(10));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.gained_coins), Some(5));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.leveled_up), Some(true));
    assert_eq!(reviewed.reward.as_ref().map(|r| r.new_level), Some(2));
    assert!(
        reviewed
            .reward
            .as_ref()
            .map(|r| !r.reward_event_id.is_nil())
            .unwrap_or(false)
    );

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn master_cannot_submit_quest_completion() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, master_claims, _hunter_claims) = ctx.seed_guild("submit_guard").await?;

    let quest = quest::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(master_claims.0.guild_id),
        title: Set("Master Submit Check".to_string()),
        description: Set(Some("Must be blocked".to_string())),
        reward_xp: Set(5),
        reward_coins: Set(2),
        stat_category: Set(QuestStatCategory::Str),
        status: Set(QuestStatus::Available),
    }
    .insert(&state.db)
    .await?;

    let err = super::submit_quest(
        HunterClaims(master_claims.0.clone()),
        State(state.clone()),
        Path(quest.id),
    )
    .await
    .expect_err("master should not submit member completion");
    assert!(matches!(err, AppError::Forbidden(_)));

    let quest_after = quest::Entity::find_by_id(quest.id)
        .one(&state.db)
        .await?
        .expect("quest should exist");
    assert_eq!(quest_after.status, QuestStatus::Available);

    ctx.cleanup().await?;
    Ok(())
}

struct TestDbContext {
    admin_db: sea_orm::DatabaseConnection,
    app_db: sea_orm::DatabaseConnection,
    db_name: String,
}

impl TestDbContext {
    async fn create() -> Result<Self, Box<dyn Error>> {
        dotenvy::dotenv().ok();
        let base_url = std::env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://chen:chen@127.0.0.1:5433/chen_leveling".to_string());
        let db_name = format!("chen_leveling_it_quests_{}", Uuid::new_v4().simple());
        let admin_url = replace_database_name(&base_url, "postgres")?;
        let test_url = replace_database_name(&base_url, &db_name)?;

        let admin_db = Database::connect(admin_url).await?;
        admin_db
            .execute(Statement::from_string(
                DatabaseBackend::Postgres,
                format!("CREATE DATABASE \"{db_name}\""),
            ))
            .await?;

        let app_db = Database::connect(test_url).await?;
        migration::Migrator::up(&app_db, None).await?;

        Ok(Self {
            admin_db,
            app_db,
            db_name,
        })
    }

    async fn seed_guild(
        &self,
        suffix: &str,
    ) -> Result<(AppState, GuildMasterClaims, HunterClaims), Box<dyn Error>> {
        let user_id = Uuid::new_v4();
        let guild_id = if suffix == "a" {
            Uuid::parse_str("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")?
        } else if suffix == "b" {
            Uuid::parse_str("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")?
        } else {
            Uuid::new_v4()
        };
        let master_hunter_id = Uuid::new_v4();
        let member_hunter_id = Uuid::new_v4();

        user::ActiveModel {
            id: Set(user_id),
            email: Set(format!("master-{suffix}@example.com")),
            password_hash: Set("$argon2id$fake$hash".to_string()),
            hunter_tag: Set(format!("ID-{}M", suffix.to_ascii_uppercase())),
            current_role: Set("Guardian".to_string()),
            created_at: Set(chrono::Utc::now()),
        }
        .insert(&self.app_db)
        .await?;

        guild::ActiveModel {
            id: Set(guild_id),
            name: Set(format!("guild-{suffix}")),
            owner_id: Set(user_id),
            invite_code: Set(format!("A{}B2C3", suffix.chars().next().unwrap_or('Z'))),
        }
        .insert(&self.app_db)
        .await?;

        hunter::ActiveModel {
            id: Set(master_hunter_id),
            guild_id: Set(guild_id),
            user_id: Set(Some(user_id)),
            player_id: Set(format!("master_{suffix}")),
            name: Set(format!("master-{suffix}")),
            avatar_type: Set("master".to_string()),
            level: Set(1),
            xp: Set(0),
            coins: Set(0),
            pin_code: Set("$argon2id$seed_master".to_string()),
            guild_role: Set("master".to_string()),
            motto: Set(None),
        }
        .insert(&self.app_db)
        .await?;
        hunter::ActiveModel {
            id: Set(member_hunter_id),
            guild_id: Set(guild_id),
            user_id: Set(None),
            player_id: Set(format!("hunter_{suffix}")),
            name: Set(format!("hunter-{suffix}")),
            avatar_type: Set("novice".to_string()),
            level: Set(1),
            xp: Set(0),
            coins: Set(0),
            pin_code: Set("$argon2id$seed_member".to_string()),
            guild_role: Set("member".to_string()),
            motto: Set(None),
        }
        .insert(&self.app_db)
        .await?;

        let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
        let state = AppState::new(self.app_db.clone(), jwt);
        let master_claims = GuildMasterClaims(Claims {
            sub: master_hunter_id,
            role: AuthRole::Player,
            guild_role: crate::jwt::GuildRole::Master,
            guild_id,
            hunter_id: Some(master_hunter_id),
            iat: 0,
            exp: 9_999_999_999,
        });
        let hunter_claims = HunterClaims(Claims {
            sub: member_hunter_id,
            role: AuthRole::Player,
            guild_role: crate::jwt::GuildRole::Member,
            guild_id,
            hunter_id: Some(member_hunter_id),
            iat: 0,
            exp: 9_999_999_999,
        });

        Ok((state, master_claims, hunter_claims))
    }

    async fn cleanup(self) -> Result<(), Box<dyn Error>> {
        self.app_db.close().await?;
        self.admin_db
            .execute(Statement::from_string(
                DatabaseBackend::Postgres,
                format!("DROP DATABASE IF EXISTS \"{}\" WITH (FORCE)", self.db_name),
            ))
            .await?;
        self.admin_db.close().await?;
        Ok(())
    }
}

fn replace_database_name(url: &str, db_name: &str) -> Result<String, Box<dyn Error>> {
    let (head, query) = match url.split_once('?') {
        Some((head, query)) => (head, Some(query)),
        None => (url, None),
    };

    let (prefix, _) = head
        .rsplit_once('/')
        .ok_or("DATABASE_URL must include a database name")?;
    let mut replaced = format!("{prefix}/{db_name}");
    if let Some(query) = query {
        replaced.push('?');
        replaced.push_str(query);
    }
    Ok(replaced)
}
