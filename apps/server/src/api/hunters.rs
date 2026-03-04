use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use entity::hunter;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DbErr, EntityTrait, QueryFilter, QueryOrder,
    SqlErr,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, GuildMasterClaims, HunterClaims},
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct CreateHunterRequest {
    pub name: String,
    pub avatar_type: String,
    pub pin_code: String,
}

#[derive(Debug, Deserialize)]
pub struct ResetHunterPinRequest {
    pub pin_code: String,
}

#[derive(Debug, Serialize)]
pub struct HunterResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub name: String,
    pub avatar_type: String,
    pub level: i32,
    pub xp: i32,
    pub coins: i32,
}

pub async fn create_hunter(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Json(payload): Json<CreateHunterRequest>,
) -> AppResult<(StatusCode, Json<HunterResponse>)> {
    let name = payload.name.trim();
    if name.is_empty() {
        return Err(AppError::BadRequest("name must not be empty".into()));
    }

    let avatar_type = payload.avatar_type.trim();
    if avatar_type.is_empty() {
        return Err(AppError::BadRequest("avatar_type must not be empty".into()));
    }

    validate_pin_code(&payload.pin_code)?;

    let model = hunter::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(claims.guild_id),
        name: Set(name.to_string()),
        avatar_type: Set(avatar_type.to_string()),
        level: Set(1),
        xp: Set(0),
        coins: Set(0),
        pin_code: Set(payload.pin_code),
    }
    .insert(&state.db)
    .await
    .map_err(|err| map_hunter_write_error(err, claims.guild_id))?;

    Ok((StatusCode::CREATED, Json(map_hunter(model))))
}

pub async fn list_hunters(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<HunterResponse>>> {
    list_hunters_for_guild(claims.guild_id, state).await
}

pub async fn list_guild_hunters(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<HunterResponse>>> {
    list_hunters_for_guild(claims.guild_id, state).await
}

async fn list_hunters_for_guild(
    guild_id: Uuid,
    state: AppState,
) -> AppResult<Json<Vec<HunterResponse>>> {
    let rows = hunter::Entity::find()
        .filter(hunter::Column::GuildId.eq(guild_id))
        .order_by_asc(hunter::Column::Name)
        .order_by_asc(hunter::Column::Id)
        .all(&state.db)
        .await?;

    Ok(Json(rows.into_iter().map(map_hunter).collect()))
}

pub async fn hunter_me(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
) -> AppResult<Json<HunterResponse>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let row = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;

    Ok(Json(map_hunter(row)))
}

pub async fn reset_hunter_pin(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Path(hunter_id): Path<Uuid>,
    Json(payload): Json<ResetHunterPinRequest>,
) -> AppResult<Json<HunterResponse>> {
    validate_pin_code(&payload.pin_code)?;

    let existing = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;

    if existing.guild_id != claims.guild_id {
        return Err(AppError::Forbidden(
            "cannot modify hunter in another guild".into(),
        ));
    }

    let mut model: hunter::ActiveModel = existing.into();
    model.pin_code = Set(payload.pin_code);
    let updated = model
        .update(&state.db)
        .await
        .map_err(|err| map_hunter_write_error(err, claims.guild_id))?;

    Ok(Json(map_hunter(updated)))
}

fn map_hunter(model: hunter::Model) -> HunterResponse {
    HunterResponse {
        id: model.id,
        guild_id: model.guild_id,
        name: model.name,
        avatar_type: model.avatar_type,
        level: model.level,
        xp: model.xp,
        coins: model.coins,
    }
}

fn validate_pin_code(pin_code: &str) -> AppResult<()> {
    if pin_code.len() != 4 || !pin_code.chars().all(|ch| ch.is_ascii_digit()) {
        return Err(AppError::BadRequest(
            "pin_code must be exactly 4 digits".into(),
        ));
    }
    Ok(())
}

fn map_hunter_write_error(err: DbErr, guild_id: Uuid) -> AppError {
    if is_hunter_pin_unique_violation(&err) {
        return AppError::Conflict(format!("pin_code is already used in guild {guild_id}"));
    }
    AppError::Database(err)
}

fn is_hunter_pin_unique_violation(err: &DbErr) -> bool {
    match err.sql_err() {
        Some(SqlErr::UniqueConstraintViolation(message)) => [
            "idx_hunters_guild_pin_unique",
            "hunters_guild_id_pin_code_key",
            "(guild_id, pin_code)",
        ]
        .iter()
        .any(|candidate| message.contains(candidate)),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;

    use axum::{
        Json,
        extract::{Path, State},
        http::StatusCode,
    };
    use chrono::Utc;
    use entity::{guild, user};
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
        CreateHunterRequest, ResetHunterPinRequest, create_hunter, hunter_me, list_guild_hunters,
        list_hunters, reset_hunter_pin,
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
            }),
        )
        .await?;

        let hunter_claims = HunterClaims(Claims {
            sub: created.id,
            role: AuthRole::Hunter,
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
            }),
        )
        .await?;

        let hunter_claims = AuthClaims(Claims {
            sub: hunter_a.id,
            role: AuthRole::Hunter,
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
                role: AuthRole::GuildMaster,
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
}
