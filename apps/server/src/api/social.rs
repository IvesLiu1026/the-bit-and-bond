use std::collections::{HashMap, HashSet};

use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use chrono::{DateTime, Utc};
use entity::{friend_link, friend_request, guild, guild_invite, hunter};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, EntityTrait, QueryFilter, QueryOrder,
    QuerySelect, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, HunterClaims},
    jwt::GuildRole,
    security::{hash_pin_code, pin_looks_hashed, verify_pin_code},
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct AddFriendRequest {
    pub player_id: String,
}

#[derive(Debug, Serialize)]
pub struct FriendProfileResponse {
    pub id: Uuid,
    pub player_id: String,
    pub name: String,
    pub guild_id: Uuid,
    pub avatar_type: String,
    pub level: i32,
    pub xp: i32,
    pub coins: i32,
}

#[derive(Debug, Deserialize)]
pub struct GuildInviteRequest {
    pub player_id: String,
}

#[derive(Debug, Deserialize)]
pub struct GuildInviteRespondRequest {
    pub accept: bool,
}

#[derive(Debug, Deserialize)]
pub struct FriendRequestCreateRequest {
    pub player_id: String,
}

#[derive(Debug, Deserialize)]
pub struct FriendRequestRespondRequest {
    pub accept: bool,
}

#[derive(Debug, Serialize)]
pub struct FriendRequestResponse {
    pub id: Uuid,
    pub requester_hunter_id: Uuid,
    pub requester_player_id: String,
    pub requester_name: String,
    pub target_hunter_id: Uuid,
    pub target_player_id: String,
    pub target_name: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub responded_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct GuildInviteResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub inviter_hunter_id: Uuid,
    pub inviter_player_id: String,
    pub inviter_name: String,
    pub invited_hunter_id: Uuid,
    pub invited_player_id: String,
    pub invited_name: String,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub responded_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct SocialProfileResponse {
    pub guild_id: Uuid,
    pub guild_name: String,
    pub role_title: String,
    pub player_id: Option<String>,
    pub hunter_tag: String,
    pub display_name: String,
    pub level: i32,
    pub xp: i32,
    pub coins: i32,
    pub motto: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateSocialProfileRequest {
    pub motto: Option<String>,
}

pub async fn add_friend(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<AddFriendRequest>,
) -> AppResult<(StatusCode, Json<FriendProfileResponse>)> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let target_player_id = normalize_player_id(&payload.player_id)?;

    let me = hunter::Entity::find_by_id(my_hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid hunter identity".into()))?;

    let target = hunter::Entity::find()
        .filter(hunter::Column::PlayerId.eq(target_player_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("找不到該玩家 ID".into()))?;

    if target.id == me.id {
        return Err(AppError::BadRequest("不能把自己加成好友".into()));
    }

    let already = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(me.id))
        .filter(friend_link::Column::FriendId.eq(target.id))
        .one(&state.db)
        .await?
        .is_some();
    if !already {
        let txn = state.db.begin().await?;
        friend_link::ActiveModel {
            id: Set(Uuid::new_v4()),
            player_id: Set(me.id),
            friend_id: Set(target.id),
            created_at: Set(Utc::now()),
        }
        .insert(&txn)
        .await
        .map_err(|_| AppError::Conflict("已經是好友或新增失敗".into()))?;

        friend_link::ActiveModel {
            id: Set(Uuid::new_v4()),
            player_id: Set(target.id),
            friend_id: Set(me.id),
            created_at: Set(Utc::now()),
        }
        .insert(&txn)
        .await
        .map_err(|_| AppError::Conflict("已經是好友或新增失敗".into()))?;
        txn.commit().await?;
    }

    Ok((StatusCode::CREATED, Json(map_friend(target))))
}

pub async fn request_friend(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<FriendRequestCreateRequest>,
) -> AppResult<(StatusCode, Json<FriendRequestResponse>)> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let target_player_id = normalize_player_id(&payload.player_id)?;

    let me = hunter::Entity::find_by_id(my_hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid hunter identity".into()))?;

    let target = hunter::Entity::find()
        .filter(hunter::Column::PlayerId.eq(target_player_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("找不到該玩家 ID".into()))?;

    if target.id == me.id {
        return Err(AppError::BadRequest("不能對自己發送好友請求".into()));
    }

    let already = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(me.id))
        .filter(friend_link::Column::FriendId.eq(target.id))
        .one(&state.db)
        .await?
        .is_some();
    if already {
        return Err(AppError::Conflict("你們已經是好友".into()));
    }

    if let Some(existing) = friend_request::Entity::find()
        .filter(friend_request::Column::Status.eq("pending"))
        .filter(
            sea_orm::Condition::any()
                .add(
                    sea_orm::Condition::all()
                        .add(friend_request::Column::RequesterHunterId.eq(me.id))
                        .add(friend_request::Column::TargetHunterId.eq(target.id)),
                )
                .add(
                    sea_orm::Condition::all()
                        .add(friend_request::Column::RequesterHunterId.eq(target.id))
                        .add(friend_request::Column::TargetHunterId.eq(me.id)),
                ),
        )
        .one(&state.db)
        .await?
    {
        return Ok((
            StatusCode::OK,
            Json(map_friend_request(existing, me, target)),
        ));
    }

    let created = friend_request::ActiveModel {
        id: Set(Uuid::new_v4()),
        requester_hunter_id: Set(me.id),
        target_hunter_id: Set(target.id),
        status: Set("pending".to_string()),
        created_at: Set(Utc::now()),
        responded_at: Set(None),
    }
    .insert(&state.db)
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(map_friend_request(created, me, target)),
    ))
}

pub async fn list_incoming_friend_requests(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<FriendRequestResponse>>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let rows = friend_request::Entity::find()
        .filter(friend_request::Column::TargetHunterId.eq(my_hunter_id))
        .filter(friend_request::Column::Status.eq("pending"))
        .order_by_desc(friend_request::Column::CreatedAt)
        .all(&state.db)
        .await?;

    let mut involved_ids = HashSet::new();
    for row in &rows {
        involved_ids.insert(row.requester_hunter_id);
        involved_ids.insert(row.target_hunter_id);
    }
    let hunter_map = load_hunter_map(&state, involved_ids).await?;

    let mut result = Vec::with_capacity(rows.len());
    for row in rows {
        let requester = hunter_map
            .get(&row.requester_hunter_id)
            .cloned()
            .ok_or_else(|| AppError::NotFound("請求者不存在".into()))?;
        let target = hunter_map
            .get(&row.target_hunter_id)
            .cloned()
            .ok_or_else(|| AppError::NotFound("目標玩家不存在".into()))?;
        result.push(map_friend_request(row, requester, target));
    }

    Ok(Json(result))
}

pub async fn respond_friend_request(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(request_id): Path<Uuid>,
    Json(payload): Json<FriendRequestRespondRequest>,
) -> AppResult<Json<FriendRequestResponse>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let request = friend_request::Entity::find_by_id(request_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("找不到好友請求".into()))?;
    if request.target_hunter_id != my_hunter_id {
        return Err(AppError::Forbidden("只能回覆自己的好友請求".into()));
    }
    if request.status != "pending" {
        return Err(AppError::BadRequest("好友請求已被處理".into()));
    }

    let txn = state.db.begin().await?;
    let mut request_am: friend_request::ActiveModel = request.clone().into();
    request_am.status = Set(if payload.accept {
        "accepted".to_string()
    } else {
        "rejected".to_string()
    });
    request_am.responded_at = Set(Some(Utc::now()));
    let updated_request = request_am.update(&txn).await?;

    if payload.accept {
        ensure_friend_link(&txn, request.requester_hunter_id, request.target_hunter_id).await?;
        ensure_friend_link(&txn, request.target_hunter_id, request.requester_hunter_id).await?;
    }
    txn.commit().await?;

    let requester = hunter::Entity::find_by_id(updated_request.requester_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("請求者不存在".into()))?;
    let target = hunter::Entity::find_by_id(updated_request.target_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("目標玩家不存在".into()))?;

    Ok(Json(map_friend_request(updated_request, requester, target)))
}

pub async fn summon_to_guild(
    claims: HunterClaims,
    state: State<AppState>,
    payload: Json<GuildInviteRequest>,
) -> AppResult<(StatusCode, Json<GuildInviteResponse>)> {
    invite_friend_to_guild(claims, state, payload).await
}

pub async fn social_profile(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
) -> AppResult<Json<SocialProfileResponse>> {
    let guild_model = guild::Entity::find_by_id(claims.guild_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("公會不存在".into()))?;

    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("token missing hunter_id".into()))?;
    let hunter_model = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("玩家不存在".into()))?;

    Ok(Json(map_social_profile(
        &guild_model,
        &hunter_model,
        claims.guild_role,
    )))
}

pub async fn update_social_profile(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<UpdateSocialProfileRequest>,
) -> AppResult<Json<SocialProfileResponse>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let existing = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("玩家不存在".into()))?;

    let mut hunter_am: hunter::ActiveModel = existing.clone().into();
    if let Some(motto_raw) = payload.motto {
        hunter_am.motto = Set(normalize_motto(&motto_raw)?);
    }
    let updated_hunter = hunter_am.update(&state.db).await?;

    let guild_model = guild::Entity::find_by_id(claims.guild_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("公會不存在".into()))?;

    Ok(Json(map_social_profile(
        &guild_model,
        &updated_hunter,
        claims.guild_role,
    )))
}

pub async fn list_friends(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<FriendProfileResponse>>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let links = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(my_hunter_id))
        .all(&state.db)
        .await?;
    if links.is_empty() {
        return Ok(Json(Vec::new()));
    }
    let friend_ids = links
        .into_iter()
        .map(|row| row.friend_id)
        .collect::<Vec<_>>();
    let rows = hunter::Entity::find()
        .filter(hunter::Column::Id.is_in(friend_ids))
        .order_by_asc(hunter::Column::Name)
        .all(&state.db)
        .await?;

    Ok(Json(rows.into_iter().map(map_friend).collect()))
}

pub async fn invite_friend_to_guild(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<GuildInviteRequest>,
) -> AppResult<(StatusCode, Json<GuildInviteResponse>)> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let target_player_id = normalize_player_id(&payload.player_id)?;

    let inviter = hunter::Entity::find_by_id(my_hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid hunter identity".into()))?;

    let invited = hunter::Entity::find()
        .filter(hunter::Column::PlayerId.eq(target_player_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("找不到被邀請的玩家".into()))?;

    if invited.id == inviter.id {
        return Err(AppError::BadRequest("不能邀請自己".into()));
    }
    if invited.guild_id == inviter.guild_id {
        return Err(AppError::BadRequest("對方已經在同一個公會".into()));
    }

    let are_friends = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(inviter.id))
        .filter(friend_link::Column::FriendId.eq(invited.id))
        .one(&state.db)
        .await?
        .is_some();
    if !are_friends {
        return Err(AppError::Forbidden("請先加好友再發送公會邀請".into()));
    }

    if let Some(existing) = guild_invite::Entity::find()
        .filter(guild_invite::Column::GuildId.eq(inviter.guild_id))
        .filter(guild_invite::Column::InvitedHunterId.eq(invited.id))
        .filter(guild_invite::Column::Status.eq("pending"))
        .one(&state.db)
        .await?
    {
        let response = map_invite(existing, inviter, invited);
        return Ok((StatusCode::OK, Json(response)));
    }

    let created = guild_invite::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(inviter.guild_id),
        inviter_hunter_id: Set(inviter.id),
        invited_hunter_id: Set(invited.id),
        status: Set("pending".to_string()),
        created_at: Set(Utc::now()),
        responded_at: Set(None),
    }
    .insert(&state.db)
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(map_invite(created, inviter, invited)),
    ))
}

pub async fn list_my_guild_invites(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<GuildInviteResponse>>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let invites = guild_invite::Entity::find()
        .filter(guild_invite::Column::InvitedHunterId.eq(my_hunter_id))
        .filter(guild_invite::Column::Status.eq("pending"))
        .order_by_desc(guild_invite::Column::CreatedAt)
        .all(&state.db)
        .await?;

    let mut involved_ids = HashSet::new();
    for invite in &invites {
        involved_ids.insert(invite.inviter_hunter_id);
        involved_ids.insert(invite.invited_hunter_id);
    }
    let hunter_map = load_hunter_map(&state, involved_ids).await?;

    let mut result = Vec::with_capacity(invites.len());
    for invite in invites {
        let inviter = hunter_map
            .get(&invite.inviter_hunter_id)
            .cloned()
            .ok_or_else(|| AppError::NotFound("邀請者不存在".into()))?;
        let invited = hunter_map
            .get(&invite.invited_hunter_id)
            .cloned()
            .ok_or_else(|| AppError::NotFound("受邀者不存在".into()))?;
        result.push(map_invite(invite, inviter, invited));
    }

    Ok(Json(result))
}

async fn load_hunter_map(
    state: &AppState,
    ids: HashSet<Uuid>,
) -> AppResult<HashMap<Uuid, hunter::Model>> {
    if ids.is_empty() {
        return Ok(HashMap::new());
    }
    let rows = hunter::Entity::find()
        .filter(hunter::Column::Id.is_in(ids))
        .all(&state.db)
        .await?;
    Ok(rows.into_iter().map(|model| (model.id, model)).collect())
}

pub async fn respond_guild_invite(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(invite_id): Path<Uuid>,
    Json(payload): Json<GuildInviteRespondRequest>,
) -> AppResult<Json<GuildInviteResponse>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let invite = guild_invite::Entity::find_by_id(invite_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("找不到邀請".into()))?;
    if invite.invited_hunter_id != my_hunter_id {
        return Err(AppError::Forbidden("只能回覆自己的邀請".into()));
    }
    if invite.status != "pending" {
        return Err(AppError::BadRequest("邀請已經被處理".into()));
    }

    let txn = state.db.begin().await?;
    let mut invite_am: guild_invite::ActiveModel = invite.clone().into();
    invite_am.status = Set(if payload.accept {
        "accepted".to_string()
    } else {
        "rejected".to_string()
    });
    invite_am.responded_at = Set(Some(Utc::now()));
    let updated_invite = invite_am.update(&txn).await?;

    if payload.accept {
        let invited = hunter::Entity::find_by_id(my_hunter_id)
            .one(&txn)
            .await?
            .ok_or_else(|| AppError::NotFound("受邀玩家不存在".into()))?;
        let current_pin = invited.pin_code.clone();
        let mut invited_am: hunter::ActiveModel = invited.into();
        invited_am.guild_id = Set(updated_invite.guild_id);
        let existing_hunters = hunter::Entity::find()
            .filter(hunter::Column::GuildId.eq(updated_invite.guild_id))
            .all(&txn)
            .await?;

        if pin_looks_hashed(&current_pin) {
            let new_pin = generate_available_pin(&existing_hunters);
            invited_am.pin_code = Set(hash_pin_code(&new_pin)?);
        } else {
            let mut next_pin = current_pin;
            if pin_in_use(&existing_hunters, &next_pin) {
                next_pin = generate_available_pin(&existing_hunters);
            }
            invited_am.pin_code = Set(hash_pin_code(&next_pin)?);
        }
        invited_am.user_id = Set(None);
        invited_am.guild_role = Set("member".to_string());
        invited_am.update(&txn).await?;
    }

    txn.commit().await?;

    let inviter = hunter::Entity::find_by_id(updated_invite.inviter_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("邀請者不存在".into()))?;
    let invited = hunter::Entity::find_by_id(updated_invite.invited_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("受邀者不存在".into()))?;

    Ok(Json(map_invite(updated_invite, inviter, invited)))
}

fn map_friend(model: hunter::Model) -> FriendProfileResponse {
    FriendProfileResponse {
        id: model.id,
        player_id: model.player_id,
        name: model.name,
        guild_id: model.guild_id,
        avatar_type: model.avatar_type,
        level: model.level,
        xp: model.xp,
        coins: model.coins,
    }
}

fn map_invite(
    invite: guild_invite::Model,
    inviter: hunter::Model,
    invited: hunter::Model,
) -> GuildInviteResponse {
    GuildInviteResponse {
        id: invite.id,
        guild_id: invite.guild_id,
        inviter_hunter_id: invite.inviter_hunter_id,
        inviter_player_id: inviter.player_id,
        inviter_name: inviter.name,
        invited_hunter_id: invite.invited_hunter_id,
        invited_player_id: invited.player_id,
        invited_name: invited.name,
        status: invite.status,
        created_at: invite.created_at,
        responded_at: invite.responded_at,
    }
}

fn map_friend_request(
    request: friend_request::Model,
    requester: hunter::Model,
    target: hunter::Model,
) -> FriendRequestResponse {
    FriendRequestResponse {
        id: request.id,
        requester_hunter_id: request.requester_hunter_id,
        requester_player_id: requester.player_id,
        requester_name: requester.name,
        target_hunter_id: request.target_hunter_id,
        target_player_id: target.player_id,
        target_name: target.name,
        status: request.status,
        created_at: request.created_at,
        responded_at: request.responded_at,
    }
}

fn map_social_profile(
    guild_model: &guild::Model,
    hunter_model: &hunter::Model,
    guild_role: GuildRole,
) -> SocialProfileResponse {
    let role_title = if guild_role == GuildRole::Master {
        "公會長"
    } else {
        "成員"
    };
    SocialProfileResponse {
        guild_id: guild_model.id,
        guild_name: guild_model.name.clone(),
        role_title: role_title.to_string(),
        player_id: Some(hunter_model.player_id.clone()),
        hunter_tag: build_hunter_tag(&hunter_model.player_id),
        display_name: hunter_model.name.clone(),
        level: hunter_model.level,
        xp: hunter_model.xp,
        coins: hunter_model.coins,
        motto: hunter_model.motto.clone(),
    }
}

fn normalize_motto(raw: &str) -> AppResult<Option<String>> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    if trimmed.chars().count() > 40 {
        return Err(AppError::BadRequest("motto 最長 40 字".into()));
    }
    Ok(Some(trimmed.to_string()))
}

async fn ensure_friend_link(
    txn: &sea_orm::DatabaseTransaction,
    player_id: Uuid,
    friend_id: Uuid,
) -> AppResult<()> {
    let exists = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(player_id))
        .filter(friend_link::Column::FriendId.eq(friend_id))
        .select_only()
        .column(friend_link::Column::Id)
        .one(txn)
        .await?
        .is_some();
    if exists {
        return Ok(());
    }

    friend_link::ActiveModel {
        id: Set(Uuid::new_v4()),
        player_id: Set(player_id),
        friend_id: Set(friend_id),
        created_at: Set(Utc::now()),
    }
    .insert(txn)
    .await
    .map_err(|_| AppError::Conflict("建立好友關係失敗".into()))?;

    Ok(())
}

fn build_hunter_tag(player_id: &str) -> String {
    format!("ID-{}", player_id.to_ascii_uppercase())
}

fn normalize_player_id(raw: &str) -> AppResult<String> {
    let normalized = raw.trim().to_ascii_lowercase();
    if normalized.len() < 4 || normalized.len() > 24 {
        return Err(AppError::BadRequest("player_id 長度需為 4~24".into()));
    }
    if !normalized
        .chars()
        .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_')
    {
        return Err(AppError::BadRequest(
            "player_id 只能使用 a-z、0-9、_".into(),
        ));
    }
    Ok(normalized)
}

fn pin_in_use(existing: &[hunter::Model], candidate: &str) -> bool {
    existing
        .iter()
        .any(|row| verify_pin_code(candidate, &row.pin_code))
}

fn generate_available_pin(existing: &[hunter::Model]) -> String {
    for pin in 0..10_000 {
        let candidate = format!("{pin:04}");
        if !pin_in_use(existing, &candidate) {
            return candidate;
        }
    }
    "9999".to_string()
}
