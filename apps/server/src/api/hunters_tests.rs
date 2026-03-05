use std::error::Error;

use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use chrono::Utc;
use entity::{guild, hunter_reward_ledger, quest::QuestStatCategory, user};
use migration::MigratorTrait;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ConnectionTrait, Database, DatabaseBackend, Statement,
};
use uuid::Uuid;

use crate::{
    error::AppError,
    extractors::{AuthClaims, GuildMasterClaims, HunterClaims},
    jwt::{AuthRole, Claims, JwtService},
    state::AppState,
};

use super::{
    CreateHunterRequest, ResetHunterPinRequest, create_hunter, hunter_me, hunter_stats,
    list_guild_hunters, list_hunters, reset_hunter_pin,
};

#[tokio::test]
async fn create_and_list_hunters_only_within_guild_scope() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, claims_a, _guild_a_user) = ctx.seed_master("a").await?;
    let (_state_ignored, claims_b, _guild_b_user) = ctx.seed_master("b").await?;

    let (status, created) = create_hunter(
        claims_a.clone(),
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "Alice".to_string(),
            avatar_type: "mage".to_string(),
            pin_code: "1234".to_string(),
            player_id: None,
        }),
    )
    .await?;
    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(created.guild_id, claims_a.0.guild_id);

    let _ = create_hunter(
        claims_b,
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "Bob".to_string(),
            avatar_type: "warrior".to_string(),
            pin_code: "5678".to_string(),
            player_id: None,
        }),
    )
    .await?;

    let list = list_hunters(claims_a, State(state)).await?;
    assert_eq!(list.len(), 1);
    assert_eq!(list[0].name, "Alice");

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn reset_pin_is_forbidden_for_other_guild() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, claims_a, _guild_a_user) = ctx.seed_master("a").await?;
    let (_state_ignored, claims_b, _guild_b_user) = ctx.seed_master("b").await?;

    let (_, hunter_b) = create_hunter(
        claims_b,
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "GuildB".to_string(),
            avatar_type: "archer".to_string(),
            pin_code: "8888".to_string(),
            player_id: None,
        }),
    )
    .await?;

    let err = reset_hunter_pin(
        claims_a,
        State(state),
        Path(hunter_b.id),
        Json(ResetHunterPinRequest {
            pin_code: "9999".to_string(),
        }),
    )
    .await
    .expect_err("must be forbidden cross guild");

    assert!(matches!(err, AppError::Forbidden(_)));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn create_hunter_rejects_pin_collision_within_same_guild() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, claims, _guild_user) = ctx.seed_master("solo").await?;

    let _ = create_hunter(
        claims.clone(),
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "First".to_string(),
            avatar_type: "mage".to_string(),
            pin_code: "2222".to_string(),
            player_id: None,
        }),
    )
    .await?;

    let err = create_hunter(
        claims,
        State(state),
        Json(CreateHunterRequest {
            name: "Second".to_string(),
            avatar_type: "warrior".to_string(),
            pin_code: "2222".to_string(),
            player_id: None,
        }),
    )
    .await
    .expect_err("same pin in same guild should conflict");

    assert!(matches!(err, AppError::Conflict(_)));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn hunter_me_returns_hunter_profile() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, master_claims, _guild_user) = ctx.seed_master("me").await?;

    let (_, created) = create_hunter(
        master_claims.clone(),
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "LittleMe".to_string(),
            avatar_type: "mage".to_string(),
            pin_code: "1357".to_string(),
            player_id: None,
        }),
    )
    .await?;

    let hunter_claims = HunterClaims(Claims {
        sub: created.id,
        role: AuthRole::Player,
        guild_role: crate::jwt::GuildRole::Member,
        guild_id: created.guild_id,
        hunter_id: Some(created.id),
        iat: 0,
        exp: 9_999_999_999,
    });

    let me = hunter_me(hunter_claims, State(state)).await?;
    assert_eq!(me.id, created.id);
    assert_eq!(me.guild_id, created.guild_id);
    assert_eq!(me.name, "LittleMe");

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn roster_is_available_for_hunter_and_still_guild_scoped() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, claims_a, _guild_a_user) = ctx.seed_master("a").await?;
    let (_state_ignored, claims_b, _guild_b_user) = ctx.seed_master("b").await?;

    let (_, hunter_a) = create_hunter(
        claims_a.clone(),
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "Alice".to_string(),
            avatar_type: "mage".to_string(),
            pin_code: "2468".to_string(),
            player_id: None,
        }),
    )
    .await?;
    let _ = create_hunter(
        claims_b,
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "Bob".to_string(),
            avatar_type: "warrior".to_string(),
            pin_code: "8642".to_string(),
            player_id: None,
        }),
    )
    .await?;

    let hunter_claims = AuthClaims(Claims {
        sub: hunter_a.id,
        role: AuthRole::Player,
        guild_role: crate::jwt::GuildRole::Member,
        guild_id: hunter_a.guild_id,
        hunter_id: Some(hunter_a.id),
        iat: 0,
        exp: 9_999_999_999,
    });

    let roster = list_guild_hunters(hunter_claims, State(state)).await?;
    assert_eq!(roster.len(), 1);
    assert_eq!(roster[0].name, "Alice");

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn hunter_stats_aggregates_ledger_and_respects_scope() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, master_claims, _guild_user) = ctx.seed_master("stats").await?;
    let (_, hunter_a) = create_hunter(
        master_claims.clone(),
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "Scout".to_string(),
            avatar_type: "rogue".to_string(),
            pin_code: "2468".to_string(),
            player_id: None,
        }),
    )
    .await?;
    let (_, hunter_b) = create_hunter(
        master_claims.clone(),
        State(state.clone()),
        Json(CreateHunterRequest {
            name: "Mage".to_string(),
            avatar_type: "mage".to_string(),
            pin_code: "8642".to_string(),
            player_id: None,
        }),
    )
    .await?;

    hunter_reward_ledger::ActiveModel {
        id: Set(Uuid::new_v4()),
        hunter_id: Set(hunter_a.id),
        quest_id: Set(None),
        item_id: Set(None),
        idempotency_key: Set(None),
        event_type: Set(hunter_reward_ledger::LedgerEventType::QuestReward),
        stat_category: Set(QuestStatCategory::Str),
        gained_xp: Set(40),
        gained_coins: Set(10),
        created_at: Set(Utc::now().into()),
    }
    .insert(&state.db)
    .await?;
    hunter_reward_ledger::ActiveModel {
        id: Set(Uuid::new_v4()),
        hunter_id: Set(hunter_a.id),
        quest_id: Set(None),
        item_id: Set(None),
        idempotency_key: Set(None),
        event_type: Set(hunter_reward_ledger::LedgerEventType::QuestReward),
        stat_category: Set(QuestStatCategory::Int),
        gained_xp: Set(25),
        gained_coins: Set(5),
        created_at: Set(Utc::now().into()),
    }
    .insert(&state.db)
    .await?;

    let stats = hunter_stats(
        AuthClaims(master_claims.0.clone()),
        State(state.clone()),
        Path(hunter_a.id),
    )
    .await?;
    assert_eq!(stats.hunter_id, hunter_a.id);
    assert_eq!(stats.stat_xp.str_xp, 40);
    assert_eq!(stats.stat_xp.int_xp, 25);
    assert_eq!(stats.total_xp, 65);
    assert_eq!(stats.total_coins, 15);
    assert_eq!(stats.entry_count, 2);

    let member_claims = AuthClaims(Claims {
        sub: hunter_a.id,
        role: AuthRole::Player,
        guild_role: crate::jwt::GuildRole::Member,
        guild_id: hunter_a.guild_id,
        hunter_id: Some(hunter_a.id),
        iat: 0,
        exp: 9_999_999_999,
    });
    let err = hunter_stats(member_claims, State(state.clone()), Path(hunter_b.id))
        .await
        .expect_err("member should not read peer stats");
    assert!(matches!(err, AppError::Forbidden(_)));

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
        let db_name = format!("chen_leveling_it_hunters_{}", Uuid::new_v4().simple());
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

    async fn seed_master(
        &self,
        suffix: &str,
    ) -> Result<(AppState, GuildMasterClaims, user::Model), Box<dyn Error>> {
        let user_id = Uuid::new_v4();
        let guild_id = Uuid::new_v4();

        let user = user::ActiveModel {
            id: Set(user_id),
            email: Set(format!("master-{suffix}@example.com")),
            password_hash: Set("$argon2id$fake$hash".to_string()),
            hunter_tag: Set(format!("ID-{}M", suffix.to_ascii_uppercase())),
            current_role: Set("Guardian".to_string()),
            created_at: Set(Utc::now()),
        }
        .insert(&self.app_db)
        .await?;

        guild::ActiveModel {
            id: Set(guild_id),
            name: Set(format!("guild-{suffix}")),
            owner_id: Set(user_id),
            invite_code: Set(format!("A{suffix}B2C").chars().take(6).collect()),
        }
        .insert(&self.app_db)
        .await?;

        let state = AppState::new(
            self.app_db.clone(),
            JwtService::new(b"0123456789abcdef0123456789abcdef", 3600),
        );
        let claims = GuildMasterClaims(Claims {
            sub: user_id,
            role: AuthRole::Player,
            guild_role: crate::jwt::GuildRole::Master,
            guild_id,
            hunter_id: None,
            iat: 0,
            exp: 9_999_999_999,
        });

        Ok((state, claims, user))
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
