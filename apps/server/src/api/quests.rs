use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use entity::{
    hunter,
    quest::{self, QuestStatus},
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DatabaseTransaction, EntityTrait, QueryFilter,
    QueryOrder, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, GuildMasterClaims, HunterClaims},
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct CreateQuestRequest {
    pub title: String,
    pub description: Option<String>,
    pub reward_xp: i32,
    pub reward_coins: i32,
}

#[derive(Debug, Deserialize)]
pub struct ReviewQuestRequest {
    pub approved: bool,
    pub hunter_id: Option<Uuid>,
}

#[derive(Debug, Serialize)]
pub struct QuestResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub reward_xp: i32,
    pub reward_coins: i32,
    pub status: QuestStatus,
}

#[derive(Debug, Serialize)]
pub struct HunterRewardResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub level: i32,
    pub xp: i32,
    pub coins: i32,
}

#[derive(Debug, Serialize)]
pub struct ReviewQuestResponse {
    pub quest: QuestResponse,
    pub hunter: Option<HunterRewardResponse>,
}

pub async fn create_quest(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Json(payload): Json<CreateQuestRequest>,
) -> AppResult<(StatusCode, Json<QuestResponse>)> {
    let title = payload.title.trim();
    if title.is_empty() {
        return Err(AppError::BadRequest("title must not be empty".into()));
    }
    if payload.reward_xp < 0 {
        return Err(AppError::BadRequest("reward_xp must be >= 0".into()));
    }
    if payload.reward_coins < 0 {
        return Err(AppError::BadRequest("reward_coins must be >= 0".into()));
    }

    let description = payload
        .description
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string);

    let created = quest::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(claims.guild_id),
        title: Set(title.to_string()),
        description: Set(description),
        reward_xp: Set(payload.reward_xp),
        reward_coins: Set(payload.reward_coins),
        status: Set(QuestStatus::Available),
    }
    .insert(&state.db)
    .await?;

    Ok((StatusCode::CREATED, Json(map_quest(created))))
}

pub async fn list_quests(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<QuestResponse>>> {
    let rows = quest::Entity::find()
        .filter(quest::Column::GuildId.eq(claims.guild_id))
        .order_by_asc(quest::Column::Title)
        .order_by_asc(quest::Column::Id)
        .all(&state.db)
        .await?;

    Ok(Json(rows.into_iter().map(map_quest).collect()))
}

pub async fn submit_quest(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(quest_id): Path<Uuid>,
) -> AppResult<Json<QuestResponse>> {
    let mut model = quest::Entity::find_by_id(quest_id)
        .filter(quest::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("quest not found".into()))?;

    if model.status != QuestStatus::Available {
        return Err(AppError::BadRequest(
            "quest must be in available status to submit".into(),
        ));
    }

    let mut active: quest::ActiveModel = model.into();
    active.status = Set(QuestStatus::PendingReview);
    model = active.update(&state.db).await?;
    Ok(Json(map_quest(model)))
}

pub async fn review_quest(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Path(quest_id): Path<Uuid>,
    Json(payload): Json<ReviewQuestRequest>,
) -> AppResult<Json<ReviewQuestResponse>> {
    let txn = state.db.begin().await?;

    let current_quest = match quest::Entity::find_by_id(quest_id)
        .filter(quest::Column::GuildId.eq(claims.guild_id))
        .one(&txn)
        .await?
    {
        Some(row) => row,
        None => return rollback(txn, AppError::NotFound("quest not found".into())).await,
    };

    if current_quest.status != QuestStatus::PendingReview {
        return rollback(
            txn,
            AppError::BadRequest("quest must be pending_review before review".into()),
        )
        .await;
    }

    if !payload.approved {
        let mut quest_am: quest::ActiveModel = current_quest.into();
        quest_am.status = Set(QuestStatus::Available);
        let updated_quest = quest_am.update(&txn).await?;
        txn.commit().await?;
        return Ok(Json(ReviewQuestResponse {
            quest: map_quest(updated_quest),
            hunter: None,
        }));
    }

    let hunter_id = match payload.hunter_id {
        Some(id) => id,
        None => {
            return rollback(
                txn,
                AppError::BadRequest("hunter_id is required when approved=true".into()),
            )
            .await;
        }
    };

    let mut quest_am: quest::ActiveModel = current_quest.into();
    quest_am.status = Set(QuestStatus::Completed);
    let updated_quest = quest_am.update(&txn).await?;

    let hunter_model = match hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&txn)
        .await?
    {
        Some(row) => row,
        None => {
            return rollback(
                txn,
                AppError::BadRequest("hunter_id does not exist in current guild".into()),
            )
            .await;
        }
    };

    let next_xp = match hunter_model.xp.checked_add(updated_quest.reward_xp) {
        Some(v) => v,
        None => return rollback(txn, AppError::BadRequest("xp overflow".into())).await,
    };
    let next_coins = match hunter_model.coins.checked_add(updated_quest.reward_coins) {
        Some(v) => v,
        None => return rollback(txn, AppError::BadRequest("coins overflow".into())).await,
    };

    let mut hunter_am: hunter::ActiveModel = hunter_model.into();
    hunter_am.xp = Set(next_xp);
    hunter_am.coins = Set(next_coins);
    let updated_hunter = hunter_am.update(&txn).await?;

    txn.commit().await?;

    Ok(Json(ReviewQuestResponse {
        quest: map_quest(updated_quest),
        hunter: Some(HunterRewardResponse {
            id: updated_hunter.id,
            guild_id: updated_hunter.guild_id,
            level: updated_hunter.level,
            xp: updated_hunter.xp,
            coins: updated_hunter.coins,
        }),
    }))
}

async fn rollback<T>(txn: DatabaseTransaction, err: AppError) -> AppResult<T> {
    txn.rollback().await?;
    Err(err)
}

fn map_quest(model: quest::Model) -> QuestResponse {
    QuestResponse {
        id: model.id,
        guild_id: model.guild_id,
        title: model.title,
        description: model.description,
        reward_xp: model.reward_xp,
        reward_coins: model.reward_coins,
        status: model.status,
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;

    use axum::{
        Json,
        body::Body,
        extract::{Path, State},
        http::{Request, StatusCode},
    };
    use entity::{
        guild, hunter,
        quest::{self, QuestStatus},
        user,
    };
    use migration::MigratorTrait;
    use sea_orm::{
        ActiveModelTrait, ActiveValue::Set, ConnectionTrait, Database, DatabaseBackend,
        EntityTrait, Statement,
    };
    use tower::ServiceExt;
    use uuid::Uuid;

    use crate::{
        app::build_router,
        error::AppError,
        extractors::{GuildMasterClaims, HunterClaims},
        jwt::{AuthRole, Claims, JwtService},
        state::AppState,
    };

    use super::{CreateQuestRequest, ReviewQuestRequest, create_quest, review_quest};

    #[tokio::test]
    async fn hunter_token_cannot_create_quest() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, _master_claims, hunter_claims) = ctx.seed_guild("a").await?;
        let token = state
            .jwt
            .issue_hunter_token(hunter_claims.0.sub, hunter_claims.0.guild_id)?
            .access_token;

        let app = build_router(state, "*")?;
        let request = Request::builder()
            .method("POST")
            .uri("/api/v1/quests")
            .header("content-type", "application/json")
            .header("authorization", format!("Bearer {token}"))
            .body(Body::from(
                r#"{"title":"Math","description":"Do worksheet","reward_xp":20,"reward_coins":5}"#,
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
    async fn review_rollback_keeps_quest_pending_when_reward_overflows()
    -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, master_claims, hunter_claims) = ctx.seed_guild("overflow").await?;

        let quest = quest::ActiveModel {
            id: Set(Uuid::new_v4()),
            guild_id: Set(master_claims.0.guild_id),
            title: Set("Overflow Quest".to_string()),
            description: Set(None),
            reward_xp: Set(1),
            reward_coins: Set(1),
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
            }),
        )
        .await?;

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
        assert_eq!(reviewed.hunter.as_ref().map(|h| h.xp), Some(10));
        assert_eq!(reviewed.hunter.as_ref().map(|h| h.coins), Some(3));

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
            let base_url = std::env::var("DATABASE_URL").unwrap_or_else(|_| {
                "postgres://chen:chen@127.0.0.1:5433/chen_leveling".to_string()
            });
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
            let hunter_id = Uuid::new_v4();

            user::ActiveModel {
                id: Set(user_id),
                email: Set(format!("master-{suffix}@example.com")),
                password_hash: Set("$argon2id$fake$hash".to_string()),
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
                id: Set(hunter_id),
                guild_id: Set(guild_id),
                name: Set(format!("hunter-{suffix}")),
                avatar_type: Set("novice".to_string()),
                level: Set(1),
                xp: Set(0),
                coins: Set(0),
                pin_code: Set("1234".to_string()),
            }
            .insert(&self.app_db)
            .await?;

            let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
            let state = AppState::new(self.app_db.clone(), jwt);
            let master_claims = GuildMasterClaims(Claims {
                sub: user_id,
                role: AuthRole::GuildMaster,
                guild_id,
                hunter_id: None,
                iat: 0,
                exp: 9_999_999_999,
            });
            let hunter_claims = HunterClaims(Claims {
                sub: hunter_id,
                role: AuthRole::Hunter,
                guild_id,
                hunter_id: Some(hunter_id),
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
}
