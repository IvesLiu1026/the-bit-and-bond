use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};
use axum::{Json, extract::State};
use chrono::Utc;
use entity::{guild, hunter, user};
use rand::Rng;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, DbErr, EntityTrait,
    QueryFilter, SqlErr, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    domain::player_identity::normalize_player_id_with_messages,
    error::{AppError, AppResult},
    extractors::AuthClaims,
    firebase_identity::{FirebaseIdentity, verify_firebase_id_token},
    jwt::{AuthRole, GuildRole, IssuedToken},
    security::{hash_pin_code, pin_looks_hashed, validate_pin_code, verify_pin_code},
    state::AppState,
};

const INVITE_CODE_ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const INVITE_CODE_LEN: usize = 6;
const INVITE_CODE_MAX_RETRIES: usize = 10;

#[derive(Debug, Deserialize)]
pub struct PlayerRegisterRequest {
    pub player_id: String,
    pub pin_code: String,
    pub display_name: String,
    pub avatar_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct PlayerLoginRequest {
    pub player_id: String,
    pub pin_code: String,
}

#[derive(Debug, Deserialize)]
pub struct UnifiedLoginRequest {
    pub account: String,
    pub secret: String,
}

#[derive(Debug, Deserialize)]
pub struct UnifiedRegisterRequest {
    pub account: String,
    pub secret: String,
    pub display_name: String,
    pub avatar_type: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct FirebaseLoginRequest {
    pub id_token: String,
    pub display_name: Option<String>,
    pub avatar_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub access_token: String,
    pub token_type: &'static str,
    pub expires_in: i64,
    pub role: AuthRole,
    pub guild_role: GuildRole,
    pub guild_id: Uuid,
    pub hunter_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub invite_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub player_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub display_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_type: Option<String>,
}

impl LoginResponse {
    fn from_issued(token: IssuedToken) -> Self {
        Self {
            access_token: token.access_token,
            token_type: "Bearer",
            expires_in: token.expires_in,
            role: token.claims.role,
            guild_role: token.claims.guild_role,
            guild_id: token.claims.guild_id,
            hunter_id: token.claims.hunter_id,
            invite_code: None,
            player_id: None,
            display_name: None,
            avatar_type: None,
        }
    }

    fn with_player(
        mut self,
        player_id: Option<String>,
        display_name: Option<String>,
        avatar_type: Option<String>,
    ) -> Self {
        self.player_id = player_id;
        self.display_name = display_name;
        self.avatar_type = avatar_type;
        self
    }
}

pub async fn player_register(
    State(state): State<AppState>,
    Json(payload): Json<PlayerRegisterRequest>,
) -> AppResult<(axum::http::StatusCode, Json<LoginResponse>)> {
    let response = register_player_with_code_factory(&state, payload, generate_invite_code).await?;
    Ok((axum::http::StatusCode::CREATED, Json(response)))
}

async fn register_player_with_code_factory<F>(
    state: &AppState,
    payload: PlayerRegisterRequest,
    mut code_factory: F,
) -> AppResult<LoginResponse>
where
    F: FnMut() -> String,
{
    let player_id = normalize_player_id(&payload.player_id)?;
    let normalized_pin = validate_pin_code(&payload.pin_code)?;
    let display_name = payload.display_name.trim();
    if display_name.is_empty() {
        return Err(AppError::BadRequest(
            "display_name must not be empty".into(),
        ));
    }

    let avatar_type = payload
        .avatar_type
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .unwrap_or("novice")
        .to_string();

    let synthetic_email = format!("player_{player_id}@players.local");
    let synthetic_password = format!("player-login:{}:{}", normalized_pin, Uuid::new_v4());
    let password_hash = hash_password(&synthetic_password)?;

    for _ in 0..INVITE_CODE_MAX_RETRIES {
        let invite_code = code_factory();
        let now = Utc::now();
        let user_id = Uuid::new_v4();
        let guild_id = Uuid::new_v4();
        let hunter_id = Uuid::new_v4();

        let txn = state.db.begin().await?;

        let created_user = match (user::ActiveModel {
            id: Set(user_id),
            email: Set(synthetic_email.clone()),
            password_hash: Set(password_hash.clone()),
            hunter_tag: Set(format!("ID-{}", player_id.to_ascii_uppercase())),
            current_role: Set("Explorer".to_string()),
            created_at: Set(now),
        }
        .insert(&txn)
        .await)
        {
            Ok(model) => model,
            Err(err) => {
                txn.rollback().await?;
                if is_users_email_unique_violation(&err) {
                    return Err(AppError::Conflict("player_id is already registered".into()));
                }
                return Err(err.into());
            }
        };

        let created_guild = match (guild::ActiveModel {
            id: Set(guild_id),
            name: Set(format!("{display_name} 的公會")),
            owner_id: Set(created_user.id),
            invite_code: Set(invite_code),
        }
        .insert(&txn)
        .await)
        {
            Ok(model) => model,
            Err(err) => {
                txn.rollback().await?;
                if is_guild_invite_code_unique_violation(&err) {
                    continue;
                }
                return Err(err.into());
            }
        };

        let created_hunter = match (hunter::ActiveModel {
            id: Set(hunter_id),
            guild_id: Set(created_guild.id),
            user_id: Set(Some(created_user.id)),
            player_id: Set(player_id.clone()),
            name: Set(display_name.to_string()),
            avatar_type: Set(avatar_type.clone()),
            level: Set(1),
            xp: Set(0),
            coins: Set(0),
            pin_code: Set(hash_pin_code(&normalized_pin)?),
            guild_role: Set("master".to_string()),
            motto: Set(None),
        }
        .insert(&txn)
        .await)
        {
            Ok(model) => model,
            Err(err) => {
                txn.rollback().await?;
                if is_hunter_player_id_unique_violation(&err) {
                    return Err(AppError::Conflict("player_id is already registered".into()));
                }
                if is_hunter_guild_pin_unique_violation(&err) {
                    return Err(AppError::Conflict(
                        "pin_code is already used in this guild".into(),
                    ));
                }
                return Err(err.into());
            }
        };

        txn.commit().await?;
        let token = state.jwt.issue_player_token(
            created_hunter.id,
            created_hunter.guild_id,
            GuildRole::Master,
        )?;
        return Ok(LoginResponse::from_issued(token).with_player(
            Some(created_hunter.player_id),
            Some(created_hunter.name),
            Some(created_hunter.avatar_type),
        ));
    }

    Err(AppError::Conflict(
        "failed to create guild invite code, please retry".into(),
    ))
}

pub async fn player_login(
    State(state): State<AppState>,
    Json(payload): Json<PlayerLoginRequest>,
) -> AppResult<Json<LoginResponse>> {
    let player_id = normalize_player_id(&payload.player_id)?;
    let normalized_pin = validate_pin_code(&payload.pin_code)?;

    let mut hunter = hunter::Entity::find()
        .filter(hunter::Column::PlayerId.eq(player_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("player_id 或 pin_code 錯誤".into()))?;
    if !verify_pin_code(&normalized_pin, &hunter.pin_code) {
        return Err(AppError::Unauthorized("player_id 或 pin_code 錯誤".into()));
    }
    if !pin_looks_hashed(&hunter.pin_code) {
        let mut hunter_am: hunter::ActiveModel = hunter.clone().into();
        hunter_am.pin_code = Set(hash_pin_code(&normalized_pin)?);
        hunter = hunter_am.update(&state.db).await?;
    }

    let token = state.jwt.issue_player_token(
        hunter.id,
        hunter.guild_id,
        parse_guild_role(&hunter.guild_role),
    )?;
    Ok(Json(LoginResponse::from_issued(token).with_player(
        Some(hunter.player_id),
        Some(hunter.name),
        Some(hunter.avatar_type),
    )))
}

pub async fn unified_register(
    State(state): State<AppState>,
    Json(payload): Json<UnifiedRegisterRequest>,
) -> AppResult<(axum::http::StatusCode, Json<LoginResponse>)> {
    let register = PlayerRegisterRequest {
        player_id: payload.account,
        pin_code: payload.secret,
        display_name: payload.display_name,
        avatar_type: payload.avatar_type,
    };
    player_register(State(state), Json(register)).await
}

pub async fn unified_login(
    State(state): State<AppState>,
    Json(payload): Json<UnifiedLoginRequest>,
) -> AppResult<Json<LoginResponse>> {
    let account = payload.account.trim();
    let secret = payload.secret.trim().to_string();
    let throttle_key = login_throttle_key(account);

    let blocked_seconds = state.auth_throttle.blocked_seconds(&throttle_key).await;
    if blocked_seconds > 0 {
        return Err(AppError::TooManyRequests(format!(
            "登入嘗試過多，請在 {blocked_seconds} 秒後再試"
        )));
    }
    let result = if account.contains('@') {
        login_with_email_password(&state, account, &secret).await
    } else {
        let player_login_payload = PlayerLoginRequest {
            player_id: account.to_string(),
            pin_code: secret,
        };
        player_login(State(state.clone()), Json(player_login_payload)).await
    };

    match result {
        Ok(response) => {
            state.auth_throttle.record_success(&throttle_key).await;
            Ok(response)
        }
        Err(err @ AppError::Unauthorized(_)) => {
            state.auth_throttle.record_failure(&throttle_key).await;
            Err(err)
        }
        Err(err) => Err(err),
    }
}

pub async fn firebase_login(
    State(state): State<AppState>,
    Json(payload): Json<FirebaseLoginRequest>,
) -> AppResult<Json<LoginResponse>> {
    let firebase_auth = state
        .firebase_auth
        .as_ref()
        .ok_or_else(|| AppError::ServiceUnavailable("firebase sign-in is not configured".into()))?;
    let identity =
        verify_firebase_id_token(&firebase_auth.project_id, payload.id_token.trim()).await?;
    let response =
        login_with_firebase_identity(&state, identity, payload.display_name, payload.avatar_type)
            .await?;
    Ok(Json(response))
}

#[derive(Debug, Serialize)]
pub struct MeResponse {
    pub sub: Uuid,
    pub role: AuthRole,
    pub guild_role: GuildRole,
    pub guild_id: Uuid,
    pub hunter_id: Option<Uuid>,
    pub player_id: Option<String>,
    pub display_name: Option<String>,
    pub avatar_type: Option<String>,
}

pub async fn me(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
) -> AppResult<Json<MeResponse>> {
    let (player_id, display_name, avatar_type) = resolve_hunter_identity(&state, &claims).await?;
    Ok(Json(MeResponse {
        sub: claims.sub,
        role: claims.role,
        guild_role: claims.guild_role,
        guild_id: claims.guild_id,
        hunter_id: claims.hunter_id,
        player_id,
        display_name,
        avatar_type,
    }))
}

async fn login_with_email_password(
    state: &AppState,
    account: &str,
    secret: &str,
) -> AppResult<Json<LoginResponse>> {
    let normalized_email = account.trim().to_ascii_lowercase();
    let user = user::Entity::find()
        .filter(user::Column::Email.eq(normalized_email))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid email or password".into()))?;
    verify_password(secret, &user.password_hash)?;

    let guild = guild::Entity::find()
        .filter(guild::Column::OwnerId.eq(user.id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid email or password".into()))?;

    let owner_hunter = ensure_owner_hunter_for_guild(state, guild.id, user.id).await?;
    let token =
        state
            .jwt
            .issue_player_token(owner_hunter.id, owner_hunter.guild_id, GuildRole::Master)?;
    Ok(Json(LoginResponse::from_issued(token).with_player(
        Some(owner_hunter.player_id),
        Some(owner_hunter.name),
        Some(owner_hunter.avatar_type),
    )))
}

async fn resolve_hunter_identity(
    state: &AppState,
    claims: &crate::jwt::Claims,
) -> AppResult<(Option<String>, Option<String>, Option<String>)> {
    if let Some(hunter_id) = claims.hunter_id {
        let hunter = hunter::Entity::find_by_id(hunter_id)
            .filter(hunter::Column::GuildId.eq(claims.guild_id))
            .one(&state.db)
            .await?;
        if let Some(model) = hunter {
            return Ok((
                Some(model.player_id),
                Some(model.name),
                Some(model.avatar_type),
            ));
        }
    }
    Ok((None, None, None))
}

async fn login_with_firebase_identity(
    state: &AppState,
    identity: FirebaseIdentity,
    display_name_override: Option<String>,
    avatar_type_override: Option<String>,
) -> AppResult<LoginResponse> {
    let user = match user::Entity::find()
        .filter(user::Column::Email.eq(identity.email.clone()))
        .one(&state.db)
        .await?
    {
        Some(existing) => existing,
        None => create_firebase_user(&state.db, &identity).await?,
    };

    let guild = ensure_owner_guild_for_user(
        state,
        user.id,
        choose_display_name(
            display_name_override.as_deref(),
            identity.display_name.as_deref(),
        ),
    )
    .await?;
    let owner_hunter = ensure_owner_hunter_for_guild_with_profile(
        state,
        guild.id,
        user.id,
        choose_display_name(
            display_name_override.as_deref(),
            identity.display_name.as_deref(),
        ),
        normalize_avatar_type(avatar_type_override.as_deref()),
    )
    .await?;
    let token =
        state
            .jwt
            .issue_player_token(owner_hunter.id, owner_hunter.guild_id, GuildRole::Master)?;
    Ok(LoginResponse::from_issued(token).with_player(
        Some(owner_hunter.player_id),
        Some(owner_hunter.name),
        Some(owner_hunter.avatar_type),
    ))
}

async fn create_firebase_user<C>(db: &C, identity: &FirebaseIdentity) -> AppResult<user::Model>
where
    C: ConnectionTrait,
{
    user::ActiveModel {
        id: Set(Uuid::new_v4()),
        email: Set(identity.email.clone()),
        password_hash: Set(hash_password(&format!(
            "firebase:{}:{}",
            identity.uid,
            Uuid::new_v4()
        ))?),
        hunter_tag: Set(format!(
            "GG-{}",
            &identity.uid.chars().take(8).collect::<String>()
        )),
        current_role: Set("Explorer".to_string()),
        created_at: Set(Utc::now()),
    }
    .insert(db)
    .await
    .map_err(|err| {
        if is_users_email_unique_violation(&err) {
            AppError::Conflict("firebase account email already exists".into())
        } else {
            err.into()
        }
    })
}

async fn ensure_owner_guild_for_user(
    state: &AppState,
    owner_id: Uuid,
    preferred_name: Option<&str>,
) -> AppResult<guild::Model> {
    if let Some(existing) = guild::Entity::find()
        .filter(guild::Column::OwnerId.eq(owner_id))
        .one(&state.db)
        .await?
    {
        return Ok(existing);
    }

    let guild_name = preferred_name
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| format!("{value} 的公會"))
        .unwrap_or_else(|| "The Bit and Bond 公會".to_string());

    for _ in 0..INVITE_CODE_MAX_RETRIES {
        let invite_code = generate_invite_code();
        let created = guild::ActiveModel {
            id: Set(Uuid::new_v4()),
            name: Set(guild_name.clone()),
            owner_id: Set(owner_id),
            invite_code: Set(invite_code),
        }
        .insert(&state.db)
        .await;
        match created {
            Ok(model) => return Ok(model),
            Err(err) => {
                if is_guild_invite_code_unique_violation(&err) {
                    continue;
                }
                return Err(err.into());
            }
        }
    }

    Err(AppError::Conflict(
        "failed to create guild invite code, please retry".into(),
    ))
}

async fn ensure_owner_hunter_for_guild(
    state: &AppState,
    guild_id: Uuid,
    owner_id: Uuid,
) -> AppResult<hunter::Model> {
    ensure_owner_hunter_for_guild_with_profile(state, guild_id, owner_id, None, None).await
}

async fn ensure_owner_hunter_for_guild_with_profile(
    state: &AppState,
    guild_id: Uuid,
    owner_id: Uuid,
    display_name: Option<&str>,
    avatar_type: Option<&str>,
) -> AppResult<hunter::Model> {
    let existing = hunter::Entity::find()
        .filter(hunter::Column::GuildId.eq(guild_id))
        .filter(
            sea_orm::Condition::any()
                .add(hunter::Column::UserId.eq(Some(owner_id)))
                .add(hunter::Column::GuildRole.eq("master")),
        )
        .one(&state.db)
        .await?;
    if let Some(existing) = existing {
        if existing.user_id == Some(owner_id)
            && existing.guild_role == "master"
            && display_name
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .is_none()
            && avatar_type
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .is_none()
        {
            return Ok(existing);
        }
        let mut am: hunter::ActiveModel = existing.into();
        am.user_id = Set(Some(owner_id));
        am.guild_role = Set("master".to_string());
        if let Some(display_name) = display_name
            .map(str::trim)
            .filter(|value| !value.is_empty())
        {
            am.name = Set(display_name.to_string());
        }
        if let Some(avatar_type) = avatar_type.map(str::trim).filter(|value| !value.is_empty()) {
            am.avatar_type = Set(avatar_type.to_string());
        }
        return am.update(&state.db).await.map_err(Into::into);
    }

    let player_id = pick_owner_player_id_for_user(owner_id, &state.db).await?;
    let pin_code = pick_available_pin_for_guild(guild_id, &state.db).await?;
    let created = hunter::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(guild_id),
        user_id: Set(Some(owner_id)),
        player_id: Set(player_id),
        name: Set(display_name
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .unwrap_or("公會長")
            .to_string()),
        avatar_type: Set(avatar_type
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .unwrap_or("master")
            .to_string()),
        level: Set(1),
        xp: Set(0),
        coins: Set(0),
        pin_code: Set(hash_pin_code(&pin_code)?),
        guild_role: Set("master".to_string()),
        motto: Set(None),
    }
    .insert(&state.db)
    .await?;
    Ok(created)
}

fn parse_guild_role(raw: &str) -> GuildRole {
    if raw.eq_ignore_ascii_case("master") {
        GuildRole::Master
    } else {
        GuildRole::Member
    }
}

async fn pick_owner_player_id_for_user<C>(owner_id: Uuid, db: &C) -> AppResult<String>
where
    C: ConnectionTrait,
{
    let base = format!("gm_{}", &owner_id.simple().to_string()[..8]);
    for attempt in 0..64 {
        let candidate = if attempt == 0 {
            base.clone()
        } else {
            format!("{base}_{:02}", attempt)
        };
        let exists = hunter::Entity::find()
            .filter(hunter::Column::PlayerId.eq(candidate.clone()))
            .one(db)
            .await?
            .is_some();
        if !exists {
            return Ok(candidate);
        }
    }
    Ok(format!("gm_{}", &Uuid::new_v4().simple().to_string()[..10]))
}

async fn pick_available_pin_for_guild<C>(guild_id: Uuid, db: &C) -> AppResult<String>
where
    C: ConnectionTrait,
{
    let existing = hunter::Entity::find()
        .filter(hunter::Column::GuildId.eq(guild_id))
        .all(db)
        .await?;

    for pin in 0..10_000 {
        let candidate = format!("{pin:04}");
        let in_use = existing
            .iter()
            .any(|model| verify_pin_code(&candidate, &model.pin_code));
        if !in_use {
            return Ok(candidate);
        }
    }
    Ok("9999".to_string())
}

fn normalize_player_id(raw: &str) -> AppResult<String> {
    normalize_player_id_with_messages(
        raw,
        "player_id length must be 4..24",
        "player_id can only contain a-z, 0-9, _",
    )
}

fn normalize_avatar_type(raw: Option<&str>) -> Option<&str> {
    raw.map(str::trim).filter(|value| !value.is_empty())
}

fn choose_display_name<'a>(primary: Option<&'a str>, fallback: Option<&'a str>) -> Option<&'a str> {
    primary
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .or_else(|| fallback.map(str::trim).filter(|value| !value.is_empty()))
}

fn login_throttle_key(account: &str) -> String {
    format!("acct:{}", account.trim().to_ascii_lowercase())
}

fn is_hunter_player_id_unique_violation(err: &DbErr) -> bool {
    is_unique_violation(
        err,
        &[
            "idx_hunters_player_id_unique",
            "hunters_player_id_key",
            "(player_id)",
        ],
    )
}

fn is_hunter_guild_pin_unique_violation(err: &DbErr) -> bool {
    is_unique_violation(
        err,
        &[
            "idx_hunters_guild_pin_unique",
            "hunters_guild_id_pin_code_key",
            "(guild_id, pin_code)",
        ],
    )
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
#[path = "auth_tests.rs"]
mod tests;
