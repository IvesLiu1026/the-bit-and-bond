use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};
use axum::{Json, extract::State};
use chrono::Utc;
use entity::{guild, hunter, user};
use rand::Rng;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DbErr, EntityTrait, QueryFilter, SqlErr,
    TransactionTrait,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, GuildMasterClaims, HunterClaims},
    jwt::{AuthRole, IssuedToken},
    state::AppState,
};

const INVITE_CODE_ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const INVITE_CODE_LEN: usize = 6;
const INVITE_CODE_MAX_RETRIES: usize = 10;

#[derive(Debug, Deserialize)]
pub struct GuildMasterLoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct GuildMasterRegisterRequest {
    pub email: String,
    pub password: String,
    pub guild_name: String,
}

#[derive(Debug, Deserialize)]
pub struct HunterLoginRequest {
    pub invite_code: String,
    pub pin_code: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub access_token: String,
    pub token_type: &'static str,
    pub expires_in: i64,
    pub role: AuthRole,
    pub guild_id: Uuid,
    pub hunter_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub invite_code: Option<String>,
}

impl LoginResponse {
    fn from_issued(token: IssuedToken) -> Self {
        Self::from_issued_with_invite(token, None)
    }

    fn from_issued_with_invite(token: IssuedToken, invite_code: Option<String>) -> Self {
        Self {
            access_token: token.access_token,
            token_type: "Bearer",
            expires_in: token.expires_in,
            role: token.claims.role,
            guild_id: token.claims.guild_id,
            hunter_id: token.claims.hunter_id,
            invite_code,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct GuildMasterRegisterResponse {
    pub access_token: String,
    pub token_type: &'static str,
    pub expires_in: i64,
    pub role: AuthRole,
    pub guild_id: Uuid,
    pub invite_code: String,
}

impl GuildMasterRegisterResponse {
    fn from_issued(token: IssuedToken, invite_code: String) -> Self {
        Self {
            access_token: token.access_token,
            token_type: "Bearer",
            expires_in: token.expires_in,
            role: token.claims.role,
            guild_id: token.claims.guild_id,
            invite_code,
        }
    }
}

pub async fn guild_master_register(
    State(state): State<AppState>,
    Json(payload): Json<GuildMasterRegisterRequest>,
) -> AppResult<(axum::http::StatusCode, Json<GuildMasterRegisterResponse>)> {
    let response =
        register_guild_master_with_code_factory(&state, payload, generate_invite_code).await?;
    Ok((axum::http::StatusCode::CREATED, Json(response)))
}

async fn register_guild_master_with_code_factory<F>(
    state: &AppState,
    payload: GuildMasterRegisterRequest,
    mut invite_code_factory: F,
) -> AppResult<GuildMasterRegisterResponse>
where
    F: FnMut() -> String,
{
    let normalized_email = payload.email.trim().to_ascii_lowercase();
    if normalized_email.is_empty() {
        return Err(AppError::BadRequest("email must not be empty".into()));
    }

    let guild_name = payload.guild_name.trim().to_string();
    if guild_name.is_empty() {
        return Err(AppError::BadRequest("guild_name must not be empty".into()));
    }

    let password_hash = hash_password(&payload.password)?;

    for _ in 0..INVITE_CODE_MAX_RETRIES {
        let invite_code = invite_code_factory();
        let now = Utc::now();
        let user_id = Uuid::new_v4();
        let guild_id = Uuid::new_v4();
        let txn = state.db.begin().await?;

        let user_insert = user::ActiveModel {
            id: Set(user_id),
            email: Set(normalized_email.clone()),
            password_hash: Set(password_hash.clone()),
            created_at: Set(now),
        }
        .insert(&txn)
        .await;
        let created_user = match user_insert {
            Ok(model) => model,
            Err(err) => {
                txn.rollback().await?;
                if is_users_email_unique_violation(&err) {
                    return Err(AppError::Conflict("email is already registered".into()));
                }
                return Err(err.into());
            }
        };

        let guild_insert = guild::ActiveModel {
            id: Set(guild_id),
            name: Set(guild_name.clone()),
            owner_id: Set(created_user.id),
            invite_code: Set(invite_code.clone()),
        }
        .insert(&txn)
        .await;
        let created_guild = match guild_insert {
            Ok(model) => model,
            Err(err) => {
                txn.rollback().await?;
                if is_guild_invite_code_unique_violation(&err) {
                    continue;
                }
                if is_users_email_unique_violation(&err) {
                    return Err(AppError::Conflict("email is already registered".into()));
                }
                return Err(err.into());
            }
        };

        txn.commit().await?;
        let token = state
            .jwt
            .issue_guild_master_token(created_user.id, created_guild.id)?;
        return Ok(GuildMasterRegisterResponse::from_issued(
            token,
            created_guild.invite_code,
        ));
    }

    Err(AppError::Conflict(
        "failed to allocate a unique invite code, please retry".into(),
    ))
}

pub async fn guild_master_login(
    State(state): State<AppState>,
    Json(payload): Json<GuildMasterLoginRequest>,
) -> AppResult<Json<LoginResponse>> {
    let normalized_email = payload.email.trim().to_ascii_lowercase();
    let user = user::Entity::find()
        .filter(user::Column::Email.eq(normalized_email))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid email or password".into()))?;

    verify_password(&payload.password, &user.password_hash)?;

    let guild = guild::Entity::find()
        .filter(guild::Column::OwnerId.eq(user.id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid email or password".into()))?;

    let token = state.jwt.issue_guild_master_token(user.id, guild.id)?;
    Ok(Json(LoginResponse::from_issued_with_invite(
        token,
        Some(guild.invite_code),
    )))
}

pub async fn hunter_login(
    State(state): State<AppState>,
    Json(payload): Json<HunterLoginRequest>,
) -> AppResult<Json<LoginResponse>> {
    let invite_code = payload.invite_code.trim().to_ascii_uppercase();
    let guild = guild::Entity::find()
        .filter(guild::Column::InviteCode.eq(invite_code))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid invite code or pin code".into()))?;

    let hunter = hunter::Entity::find()
        .filter(hunter::Column::GuildId.eq(guild.id))
        .filter(hunter::Column::PinCode.eq(payload.pin_code.trim().to_string()))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid invite code or pin code".into()))?;

    let token = state.jwt.issue_hunter_token(hunter.id, guild.id)?;
    Ok(Json(LoginResponse::from_issued(token)))
}

#[derive(Debug, Serialize)]
pub struct MeResponse {
    pub sub: Uuid,
    pub role: AuthRole,
    pub guild_id: Uuid,
    pub hunter_id: Option<Uuid>,
}

pub async fn me(AuthClaims(claims): AuthClaims) -> Json<MeResponse> {
    Json(MeResponse {
        sub: claims.sub,
        role: claims.role,
        guild_id: claims.guild_id,
        hunter_id: claims.hunter_id,
    })
}

pub async fn guild_master_me(GuildMasterClaims(claims): GuildMasterClaims) -> Json<MeResponse> {
    Json(MeResponse {
        sub: claims.sub,
        role: claims.role,
        guild_id: claims.guild_id,
        hunter_id: claims.hunter_id,
    })
}

pub async fn hunter_me(HunterClaims(claims): HunterClaims) -> Json<MeResponse> {
    Json(MeResponse {
        sub: claims.sub,
        role: claims.role,
        guild_id: claims.guild_id,
        hunter_id: claims.hunter_id,
    })
}

pub fn hash_password(password: &str) -> AppResult<String> {
    if password.len() < 8 {
        return Err(AppError::BadRequest(
            "password must be at least 8 characters".into(),
        ));
    }

    let salt = SaltString::generate(&mut OsRng);
    let hasher = Argon2::default();
    hasher
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| AppError::BadRequest("failed to hash password".into()))
}

fn verify_password(password: &str, password_hash: &str) -> AppResult<()> {
    let parsed_hash = PasswordHash::new(password_hash)
        .map_err(|_| AppError::Unauthorized("invalid email or password".into()))?;

    Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .map_err(|_| AppError::Unauthorized("invalid email or password".into()))
}

fn generate_invite_code() -> String {
    let mut rng = rand::thread_rng();
    (0..INVITE_CODE_LEN)
        .map(|_| {
            let idx = rng.gen_range(0..INVITE_CODE_ALPHABET.len());
            INVITE_CODE_ALPHABET[idx] as char
        })
        .collect()
}

fn is_users_email_unique_violation(err: &DbErr) -> bool {
    is_unique_violation(
        err,
        &["idx_users_email_unique", "users_email_key", "(email)"],
    )
}

fn is_guild_invite_code_unique_violation(err: &DbErr) -> bool {
    is_unique_violation(
        err,
        &[
            "idx_guilds_invite_code_unique",
            "guilds_invite_code_key",
            "(invite_code)",
        ],
    )
}

fn is_unique_violation(err: &DbErr, marker_candidates: &[&str]) -> bool {
    match err.sql_err() {
        Some(SqlErr::UniqueConstraintViolation(message)) => marker_candidates
            .iter()
            .any(|candidate| message.contains(candidate)),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use axum::{Json, extract::State};
    use chrono::Utc;
    use sea_orm::{
        ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, Database,
        DatabaseBackend, EntityTrait, QueryFilter, Statement,
    };
    use std::error::Error;
    use uuid::Uuid;

    use crate::{jwt::JwtService, state::AppState};
    use entity::{guild, user};
    use migration::MigratorTrait;

    use super::{
        GuildMasterLoginRequest, GuildMasterRegisterRequest, INVITE_CODE_ALPHABET, INVITE_CODE_LEN,
        generate_invite_code, guild_master_login, guild_master_register, hash_password,
        register_guild_master_with_code_factory, verify_password,
    };

    #[test]
    fn password_hash_roundtrip() {
        let plain = "super-secret-password";
        let hash = hash_password(plain).expect("hash");
        verify_password(plain, &hash).expect("verify");
    }

    #[test]
    fn invite_code_uses_friendly_charset() {
        let code = generate_invite_code();
        assert_eq!(code.len(), INVITE_CODE_LEN);
        assert!(code.bytes().all(|ch| INVITE_CODE_ALPHABET.contains(&ch)));
    }

    #[tokio::test]
    async fn register_and_login_flow_works() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let state = ctx.app_state();
        let email = format!("master-{}@example.com", Uuid::new_v4().simple());
        let password = "Passw0rd!";

        let (status, response) = guild_master_register(
            State(state.clone()),
            Json(GuildMasterRegisterRequest {
                email: email.clone(),
                password: password.to_string(),
                guild_name: "Cozy Guild".to_string(),
            }),
        )
        .await?;
        assert_eq!(status, axum::http::StatusCode::CREATED);
        assert_eq!(response.role, crate::jwt::AuthRole::GuildMaster);
        assert_eq!(response.invite_code.len(), INVITE_CODE_LEN);

        let login_response = guild_master_login(
            State(state),
            Json(GuildMasterLoginRequest {
                email,
                password: password.to_string(),
            }),
        )
        .await?;
        assert_eq!(login_response.role, crate::jwt::AuthRole::GuildMaster);
        assert_eq!(login_response.guild_id, response.guild_id);
        assert!(login_response.hunter_id.is_none());
        assert_eq!(
            login_response.invite_code.as_deref(),
            Some(response.invite_code.as_str())
        );

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn register_rolls_back_user_when_guild_insert_fails() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let state = ctx.app_state();
        let email = format!("rollback-{}@example.com", Uuid::new_v4().simple());
        let long_name = "X".repeat(300);

        let err = guild_master_register(
            State(state.clone()),
            Json(GuildMasterRegisterRequest {
                email: email.clone(),
                password: "Passw0rd!".to_string(),
                guild_name: long_name,
            }),
        )
        .await
        .expect_err("register should fail when guild insert fails");
        assert!(matches!(err, crate::error::AppError::Database(_)));

        let maybe_user = user::Entity::find()
            .filter(user::Column::Email.eq(email))
            .one(&state.db)
            .await?;
        assert!(
            maybe_user.is_none(),
            "user insert should rollback when guild insert fails"
        );

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn register_retries_when_invite_code_collides() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let state = ctx.app_state();

        let existing_user = user::ActiveModel {
            id: Set(Uuid::new_v4()),
            email: Set(format!("existing-{}@example.com", Uuid::new_v4().simple())),
            password_hash: Set(hash_password("Passw0rd!")?),
            created_at: Set(Utc::now()),
        }
        .insert(&state.db)
        .await?;
        guild::ActiveModel {
            id: Set(Uuid::new_v4()),
            name: Set("Existing Guild".to_string()),
            owner_id: Set(existing_user.id),
            invite_code: Set("ABCDEF".to_string()),
        }
        .insert(&state.db)
        .await?;

        let mut codes = vec!["ABCDEF".to_string(), "QWERTY".to_string()].into_iter();
        let response = register_guild_master_with_code_factory(
            &state,
            GuildMasterRegisterRequest {
                email: format!("collision-{}@example.com", Uuid::new_v4().simple()),
                password: "Passw0rd!".to_string(),
                guild_name: "Retry Guild".to_string(),
            },
            || codes.next().unwrap_or_else(|| "ZXCVBN".to_string()),
        )
        .await?;

        assert_eq!(response.invite_code, "QWERTY");

        let inserted_guild = guild::Entity::find_by_id(response.guild_id)
            .one(&state.db)
            .await?
            .expect("guild should exist");
        assert_eq!(inserted_guild.invite_code, "QWERTY");

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
            let db_name = format!("chen_leveling_it_{}", Uuid::new_v4().simple());
            let admin_url = replace_database_name(&base_url, "postgres")?;
            let test_url = replace_database_name(&base_url, &db_name)?;

            let admin_db = Database::connect(admin_url).await?;
            let create_sql = format!("CREATE DATABASE \"{db_name}\"");
            admin_db
                .execute(Statement::from_string(
                    DatabaseBackend::Postgres,
                    create_sql,
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

        fn app_state(&self) -> AppState {
            let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
            AppState::new(self.app_db.clone(), jwt)
        }

        async fn cleanup(self) -> Result<(), Box<dyn Error>> {
            self.app_db.close().await?;
            let drop_sql = format!("DROP DATABASE IF EXISTS \"{}\" WITH (FORCE)", self.db_name);
            self.admin_db
                .execute(Statement::from_string(DatabaseBackend::Postgres, drop_sql))
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
