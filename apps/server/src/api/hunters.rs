use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use entity::{hunter, hunter_reward_ledger, quest::QuestStatCategory};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DbErr, EntityTrait, QueryFilter, QueryOrder,
    SqlErr,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, GuildMasterClaims, HunterClaims},
    jwt::GuildRole,
    security::{hash_pin_code, validate_pin_code, verify_pin_code},
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct CreateHunterRequest {
    pub name: String,
    pub avatar_type: String,
    pub pin_code: String,
    pub player_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ResetHunterPinRequest {
    pub pin_code: String,
}

#[derive(Debug, Serialize)]
pub struct HunterResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub player_id: String,
    pub name: String,
    pub avatar_type: String,
    pub level: i32,
    pub xp: i32,
    pub coins: i32,
}

#[derive(Debug, Serialize, Default, Clone)]
pub struct HunterStatsBreakdown {
    pub str_xp: i64,
    pub int_xp: i64,
    pub agi_xp: i64,
    pub cha_xp: i64,
    pub vit_xp: i64,
    pub none_xp: i64,
}

#[derive(Debug, Serialize, Clone)]
pub struct HunterStatsResponse {
    pub hunter_id: Uuid,
    pub guild_id: Uuid,
    pub stat_xp: HunterStatsBreakdown,
    pub total_xp: i64,
    pub total_coins: i64,
    pub entry_count: i64,
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

    let normalized_pin = validate_pin_code(&payload.pin_code)?;
    if pin_in_use_in_guild(&state.db, claims.guild_id, &normalized_pin, None).await? {
        return Err(AppError::Conflict(format!(
            "pin_code is already used in guild {}",
            claims.guild_id
        )));
    }
    let provided_player_id = match payload.player_id.as_deref() {
        Some(raw) if !raw.trim().is_empty() => Some(normalize_player_id(raw)?),
        _ => None,
    };

    for _ in 0..8 {
        let candidate_player_id = provided_player_id
            .clone()
            .unwrap_or_else(generate_random_player_id);
        let model = hunter::ActiveModel {
            id: Set(Uuid::new_v4()),
            guild_id: Set(claims.guild_id),
            user_id: Set(None),
            player_id: Set(candidate_player_id),
            name: Set(name.to_string()),
            avatar_type: Set(avatar_type.to_string()),
            level: Set(1),
            xp: Set(0),
            coins: Set(0),
            pin_code: Set(hash_pin_code(&normalized_pin)?),
            guild_role: Set("member".to_string()),
            motto: Set(None),
        }
        .insert(&state.db)
        .await;
        match model {
            Ok(model) => return Ok((StatusCode::CREATED, Json(map_hunter(model)))),
            Err(err) => {
                if is_hunter_player_id_unique_violation(&err) && provided_player_id.is_none() {
                    continue;
                }
                return Err(map_hunter_write_error(err, claims.guild_id));
            }
        }
    }

    Err(AppError::Conflict(
        "failed to allocate player_id, please retry".into(),
    ))
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

pub async fn hunter_stats(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Path(hunter_id): Path<Uuid>,
) -> AppResult<Json<HunterStatsResponse>> {
    let target = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;

    if claims.guild_role != GuildRole::Master && claims.sub != target.id {
        return Err(AppError::Forbidden(
            "cannot read another member's stats".into(),
        ));
    }

    let rows = hunter_reward_ledger::Entity::find()
        .filter(hunter_reward_ledger::Column::HunterId.eq(target.id))
        .order_by_desc(hunter_reward_ledger::Column::CreatedAt)
        .all(&state.db)
        .await?;

    let mut stat_xp = HunterStatsBreakdown::default();
    let mut total_xp = 0_i64;
    let mut total_coins = 0_i64;
    for row in &rows {
        let gained_xp = i64::from(row.gained_xp);
        let gained_coins = i64::from(row.gained_coins);
        total_xp += gained_xp;
        total_coins += gained_coins;
        match row.stat_category {
            QuestStatCategory::Str => stat_xp.str_xp += gained_xp,
            QuestStatCategory::Int => stat_xp.int_xp += gained_xp,
            QuestStatCategory::Agi => stat_xp.agi_xp += gained_xp,
            QuestStatCategory::Cha => stat_xp.cha_xp += gained_xp,
            QuestStatCategory::Vit => stat_xp.vit_xp += gained_xp,
            QuestStatCategory::None => stat_xp.none_xp += gained_xp,
        }
    }

    Ok(Json(HunterStatsResponse {
        hunter_id: target.id,
        guild_id: target.guild_id,
        stat_xp,
        total_xp,
        total_coins,
        entry_count: rows.len() as i64,
    }))
}

pub async fn reset_hunter_pin(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Path(hunter_id): Path<Uuid>,
    Json(payload): Json<ResetHunterPinRequest>,
) -> AppResult<Json<HunterResponse>> {
    let normalized_pin = validate_pin_code(&payload.pin_code)?;

    let existing = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;

    if existing.guild_id != claims.guild_id {
        return Err(AppError::Forbidden(
            "cannot modify hunter in another guild".into(),
        ));
    }
    if pin_in_use_in_guild(&state.db, claims.guild_id, &normalized_pin, Some(hunter_id)).await? {
        return Err(AppError::Conflict(format!(
            "pin_code is already used in guild {}",
            claims.guild_id
        )));
    }

    let mut model: hunter::ActiveModel = existing.into();
    model.pin_code = Set(hash_pin_code(&normalized_pin)?);
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
        player_id: model.player_id,
        name: model.name,
        avatar_type: model.avatar_type,
        level: model.level,
        xp: model.xp,
        coins: model.coins,
    }
}

fn map_hunter_write_error(err: DbErr, guild_id: Uuid) -> AppError {
    if is_hunter_pin_unique_violation(&err) {
        return AppError::Conflict(format!("pin_code is already used in guild {guild_id}"));
    }
    if is_hunter_player_id_unique_violation(&err) {
        return AppError::Conflict("player_id is already used".into());
    }
    AppError::Database(err)
}

async fn pin_in_use_in_guild<C>(
    db: &C,
    guild_id: Uuid,
    candidate_pin: &str,
    exclude_hunter_id: Option<Uuid>,
) -> AppResult<bool>
where
    C: sea_orm::ConnectionTrait,
{
    let rows = hunter::Entity::find()
        .filter(hunter::Column::GuildId.eq(guild_id))
        .all(db)
        .await?;
    for row in rows {
        if Some(row.id) == exclude_hunter_id {
            continue;
        }
        if verify_pin_code(candidate_pin, &row.pin_code) {
            return Ok(true);
        }
    }
    Ok(false)
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

fn is_hunter_player_id_unique_violation(err: &DbErr) -> bool {
    match err.sql_err() {
        Some(SqlErr::UniqueConstraintViolation(message)) => [
            "idx_hunters_player_id_unique",
            "hunters_player_id_key",
            "(player_id)",
        ]
        .iter()
        .any(|candidate| message.contains(candidate)),
        _ => false,
    }
}

fn normalize_player_id(raw: &str) -> AppResult<String> {
    let normalized = raw.trim().to_ascii_lowercase();
    if normalized.len() < 4 || normalized.len() > 24 {
        return Err(AppError::BadRequest(
            "player_id length must be between 4 and 24".into(),
        ));
    }
    if !normalized
        .chars()
        .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_')
    {
        return Err(AppError::BadRequest(
            "player_id may only contain a-z, 0-9, _".into(),
        ));
    }
    Ok(normalized)
}

fn generate_random_player_id() -> String {
    let suffix = Uuid::new_v4().simple().to_string();
    format!("p{}", &suffix[..10])
}

#[cfg(test)]
#[path = "hunters_tests.rs"]
mod tests;
