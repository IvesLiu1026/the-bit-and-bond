use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

use axum::{
    Json,
    body::Body,
    extract::{Multipart, Path, Query, State},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    response::IntoResponse,
};
use chrono::{Duration, Utc};
use entity::{
    dm_device_key, friend_link, hunter, media_asset, media_once_delivery, photo_dump_export,
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, EntityTrait, IntoActiveModel, QueryFilter,
    QueryOrder, QuerySelect,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, HunterClaims},
    state::AppState,
};

const DEFAULT_MEDIA_LIST_LIMIT: u64 = 40;
const MAX_MEDIA_LIST_LIMIT: u64 = 120;
const MAX_MEDIA_BYTE_SIZE: usize = 10 * 1024 * 1024;
const MAX_MEDIA_CAPTION_CHARS: usize = 280;
const MAX_RECIPIENT_PLAYER_ID_CHARS: usize = 40;
const ONCE_OPEN_TOKEN_TTL_SECONDS: i64 = 45;
const ONCE_OPEN_TOKEN_PREFIX: &str = "once";
const DEFAULT_ONCE_TTL_SECONDS: i64 = 24 * 60 * 60;
const MIN_ONCE_TTL_SECONDS: i64 = 10;
const MAX_ONCE_TTL_SECONDS: i64 = 7 * 24 * 60 * 60;
const MAX_EXPORT_ASSET_COUNT: usize = 24;
const MAX_DEVICE_ID_CHARS: usize = 120;
const MAX_PROTOCOL_VERSION_CHARS: usize = 40;
const MAX_NONCE_B64_CHARS: usize = 120;
const MAX_MAC_B64_CHARS: usize = 120;
const ENCRYPTION_MODE_PLAINTEXT: &str = "plaintext";
const ENCRYPTION_MODE_E2EE: &str = "e2ee";

#[derive(Debug, Clone, Serialize)]
pub struct MediaAssetResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub owner_hunter_id: Uuid,
    pub owner_name: String,
    pub owner_player_id: String,
    pub mode: String,
    pub original_filename: Option<String>,
    pub mime_type: String,
    pub byte_size: i64,
    pub caption: Option<String>,
    pub is_photo_dump_ready: bool,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub expires_at: Option<chrono::DateTime<chrono::Utc>>,
    pub content_path: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct MediaOnceDeliveryResponse {
    pub id: Uuid,
    pub media_asset_id: Uuid,
    pub guild_id: Uuid,
    pub sender_hunter_id: Uuid,
    pub sender_name: String,
    pub sender_player_id: String,
    pub recipient_hunter_id: Uuid,
    pub caption: Option<String>,
    pub mime_type: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub expires_at: Option<chrono::DateTime<chrono::Utc>>,
    pub opened_at: Option<chrono::DateTime<chrono::Utc>>,
    pub consumed_at: Option<chrono::DateTime<chrono::Utc>>,
    pub remaining_views: i32,
    pub encryption: MediaEncryptionSnapshot,
}

#[derive(Debug, Clone, Serialize)]
pub struct MediaOnceOpenResponse {
    pub delivery_id: Uuid,
    pub media_asset_id: Uuid,
    pub opened_at: chrono::DateTime<chrono::Utc>,
    pub consumed_at: Option<chrono::DateTime<chrono::Utc>>,
    pub content_path: String,
    pub token_ttl_seconds: i64,
    pub encryption: MediaEncryptionSnapshot,
}

#[derive(Debug, Clone, Serialize)]
pub struct MediaEncryptionSnapshot {
    pub mode: String,
    pub protocol_version: Option<String>,
    pub sender_device_id: Option<String>,
    pub recipient_device_id: Option<String>,
    pub nonce: Option<String>,
    pub mac: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PhotoDumpExportResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub owner_hunter_id: Uuid,
    pub title: String,
    pub style: String,
    pub asset_count: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub assets: Vec<MediaAssetResponse>,
}

#[derive(Debug, Deserialize, Default)]
pub struct MediaListQuery {
    pub limit: Option<u64>,
}

#[derive(Debug, Deserialize)]
pub struct OneTimeContentQuery {
    pub token: String,
}

#[derive(Debug, Deserialize)]
pub struct CreatePhotoDumpExportRequest {
    pub asset_ids: Vec<Uuid>,
    pub title: Option<String>,
    pub style: Option<String>,
}

pub async fn list_vault_media(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<MediaListQuery>,
) -> AppResult<Json<Vec<MediaAssetResponse>>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let limit = query
        .limit
        .unwrap_or(DEFAULT_MEDIA_LIST_LIMIT)
        .min(MAX_MEDIA_LIST_LIMIT);

    let rows = media_asset::Entity::find()
        .filter(media_asset::Column::GuildId.eq(claims.guild_id))
        .filter(media_asset::Column::OwnerHunterId.eq(hunter_id))
        .filter(media_asset::Column::Mode.eq("vault"))
        .order_by_desc(media_asset::Column::CreatedAt)
        .order_by_desc(media_asset::Column::Id)
        .limit(limit)
        .all(&state.db)
        .await?;

    let owner = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;
    let owner_name = owner.name;
    let owner_player_id = owner.player_id;

    Ok(Json(
        rows.into_iter()
            .map(|row| map_media_asset(row, &owner_name, &owner_player_id))
            .collect(),
    ))
}

pub async fn upload_vault_media(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> AppResult<(StatusCode, Json<MediaAssetResponse>)> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let owner = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;

    let payload = parse_upload_payload(&mut multipart).await?;
    let caption = normalize_caption(payload.caption)?;
    let include_in_dump = payload.include_in_dump.unwrap_or(false);
    let expires_at: Option<chrono::DateTime<Utc>> = None;

    let media_id = Uuid::new_v4();
    let extension = preferred_media_extension(payload.original_filename.as_deref(), &payload.mime);
    let storage_key = format!("photo-vault/{hunter_id}/{media_id}{extension}");
    persist_media_file(&storage_key, &payload.bytes).await?;

    let created = media_asset::ActiveModel {
        id: Set(media_id),
        guild_id: Set(claims.guild_id),
        owner_hunter_id: Set(hunter_id),
        mode: Set("vault".to_string()),
        storage_key: Set(storage_key),
        original_filename: Set(payload.original_filename),
        mime_type: Set(payload.mime),
        byte_size: Set(payload.bytes.len() as i64),
        caption: Set(caption),
        is_photo_dump_ready: Set(include_in_dump),
        created_at: Set(Utc::now().into()),
        expires_at: Set(expires_at.map(Into::into)),
    };

    let created = created.insert(&state.db).await?;
    let response = map_media_asset(created, &owner.name, &owner.player_id);
    Ok((StatusCode::CREATED, Json(response)))
}

pub async fn send_once_media(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> AppResult<(StatusCode, Json<MediaOnceDeliveryResponse>)> {
    let sender_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let sender = hunter::Entity::find_by_id(sender_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;

    let payload = parse_upload_payload(&mut multipart).await?;
    let recipient_player_id = normalize_recipient_player_id(payload.recipient_player_id)?;
    let recipient = hunter::Entity::find()
        .filter(hunter::Column::PlayerId.eq(recipient_player_id.clone()))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("recipient player_id not found".into()))?;
    if recipient.id == sender.id {
        return Err(AppError::BadRequest(
            "cannot send one-time media to self".into(),
        ));
    }

    ensure_friendship(&state, sender.id, recipient.id).await?;

    let ttl_seconds = normalize_once_ttl_seconds(payload.ttl_seconds)?;
    let now = Utc::now();
    let expires_at = now + Duration::seconds(ttl_seconds);
    let caption = normalize_caption(payload.caption)?;
    let encryption = normalize_media_encryption(
        payload.encryption_mode,
        payload.protocol_version,
        payload.sender_device_id,
        payload.recipient_device_id,
        payload.encryption_nonce,
        payload.encryption_mac,
    )?;

    if encryption.mode == ENCRYPTION_MODE_E2EE {
        let sender_device_id = encryption
            .sender_device_id
            .as_deref()
            .ok_or_else(|| AppError::BadRequest("sender_device_id is required".into()))?;
        let recipient_device_id = encryption
            .recipient_device_id
            .as_deref()
            .ok_or_else(|| AppError::BadRequest("recipient_device_id is required".into()))?;
        require_active_dm_device_key(&state, sender.id, sender_device_id).await?;
        require_active_dm_device_key(&state, recipient.id, recipient_device_id).await?;
    }

    let media_id = Uuid::new_v4();
    let extension = preferred_media_extension(payload.original_filename.as_deref(), &payload.mime);
    let storage_key = format!("photo-once/{sender_id}/{media_id}{extension}");
    persist_media_file(&storage_key, &payload.bytes).await?;

    let media = media_asset::ActiveModel {
        id: Set(media_id),
        guild_id: Set(claims.guild_id),
        owner_hunter_id: Set(sender.id),
        mode: Set("once".to_string()),
        storage_key: Set(storage_key),
        original_filename: Set(payload.original_filename),
        mime_type: Set(payload.mime),
        byte_size: Set(payload.bytes.len() as i64),
        caption: Set(caption.clone()),
        is_photo_dump_ready: Set(false),
        created_at: Set(now.into()),
        expires_at: Set(Some(expires_at.into())),
    }
    .insert(&state.db)
    .await?;

    let delivery = media_once_delivery::ActiveModel {
        id: Set(Uuid::new_v4()),
        media_asset_id: Set(media.id),
        guild_id: Set(claims.guild_id),
        sender_hunter_id: Set(sender.id),
        recipient_hunter_id: Set(recipient.id),
        remaining_views: Set(1),
        opened_at: Set(None),
        consumed_at: Set(None),
        expires_at: Set(Some(expires_at.into())),
        access_token_hash: Set(None),
        access_token_expires_at: Set(None),
        encryption_mode: Set(encryption.mode.clone()),
        protocol_version: Set(encryption.protocol_version.clone()),
        sender_device_id: Set(encryption.sender_device_id.clone()),
        recipient_device_id: Set(encryption.recipient_device_id.clone()),
        encryption_nonce: Set(encryption.nonce.clone()),
        encryption_mac: Set(encryption.mac.clone()),
        created_at: Set(now.into()),
    }
    .insert(&state.db)
    .await?;

    let response = map_once_delivery(delivery, media, &sender.name, &sender.player_id);
    Ok((StatusCode::CREATED, Json(response)))
}

pub async fn list_once_inbox(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<MediaListQuery>,
) -> AppResult<Json<Vec<MediaOnceDeliveryResponse>>> {
    let recipient_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let limit = query
        .limit
        .unwrap_or(DEFAULT_MEDIA_LIST_LIMIT)
        .min(MAX_MEDIA_LIST_LIMIT);
    let now = Utc::now();

    let deliveries = media_once_delivery::Entity::find()
        .filter(media_once_delivery::Column::RecipientHunterId.eq(recipient_id))
        .filter(media_once_delivery::Column::ConsumedAt.is_null())
        .filter(media_once_delivery::Column::RemainingViews.gt(0))
        .filter(
            sea_orm::Condition::any()
                .add(media_once_delivery::Column::ExpiresAt.is_null())
                .add(media_once_delivery::Column::ExpiresAt.gt(now)),
        )
        .order_by_desc(media_once_delivery::Column::CreatedAt)
        .order_by_desc(media_once_delivery::Column::Id)
        .limit(limit)
        .all(&state.db)
        .await?;

    let media_ids: Vec<Uuid> = deliveries.iter().map(|item| item.media_asset_id).collect();
    let media_rows = media_asset::Entity::find()
        .filter(media_asset::Column::Id.is_in(media_ids.clone()))
        .all(&state.db)
        .await?;
    let media_map: HashMap<Uuid, media_asset::Model> =
        media_rows.into_iter().map(|row| (row.id, row)).collect();

    let sender_ids: HashSet<Uuid> = deliveries
        .iter()
        .map(|item| item.sender_hunter_id)
        .collect();
    let sender_rows = hunter::Entity::find()
        .filter(hunter::Column::Id.is_in(sender_ids))
        .all(&state.db)
        .await?;
    let sender_map: HashMap<Uuid, hunter::Model> =
        sender_rows.into_iter().map(|row| (row.id, row)).collect();

    let mut result = Vec::with_capacity(deliveries.len());
    for delivery in deliveries {
        let media = media_map
            .get(&delivery.media_asset_id)
            .ok_or_else(|| AppError::NotFound("linked media asset missing".into()))?;
        let sender = sender_map
            .get(&delivery.sender_hunter_id)
            .ok_or_else(|| AppError::NotFound("sender hunter missing".into()))?;
        result.push(map_once_delivery(
            delivery,
            media.clone(),
            &sender.name,
            &sender.player_id,
        ));
    }
    Ok(Json(result))
}

pub async fn open_once_media(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(delivery_id): Path<Uuid>,
) -> AppResult<Json<MediaOnceOpenResponse>> {
    let recipient_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let mut delivery = media_once_delivery::Entity::find_by_id(delivery_id)
        .filter(media_once_delivery::Column::RecipientHunterId.eq(recipient_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("one-time media delivery not found".into()))?;

    let now = Utc::now();
    if let Some(expires_at) = delivery.expires_at
        && expires_at.with_timezone(&Utc) <= now
    {
        return Err(AppError::BadRequest("one-time media has expired".into()));
    }
    if delivery.consumed_at.is_some() || delivery.remaining_views <= 0 {
        return Err(AppError::Conflict(
            "one-time media has already been opened".into(),
        ));
    }

    let access_token = build_once_access_token();
    let access_token_hash = hash_once_access_token(&access_token);
    let access_expires_at = now + Duration::seconds(ONCE_OPEN_TOKEN_TTL_SECONDS);
    let opened_at = delivery.opened_at.unwrap_or_else(|| now.into());

    let mut active = delivery.into_active_model();
    active.opened_at = Set(Some(opened_at));
    active.access_token_hash = Set(Some(access_token_hash));
    active.access_token_expires_at = Set(Some(access_expires_at.into()));
    delivery = active.update(&state.db).await?;

    let content_path = format!(
        "/api/v1/media/once/{}/content?token={}",
        delivery.id, access_token
    );
    Ok(Json(MediaOnceOpenResponse {
        delivery_id: delivery.id,
        media_asset_id: delivery.media_asset_id,
        opened_at: delivery
            .opened_at
            .map(|value| value.with_timezone(&Utc))
            .unwrap_or(now),
        consumed_at: delivery.consumed_at.map(|value| value.with_timezone(&Utc)),
        content_path,
        token_ttl_seconds: ONCE_OPEN_TOKEN_TTL_SECONDS,
        encryption: map_media_encryption_snapshot(&delivery),
    }))
}

pub async fn get_once_media_content(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Path(delivery_id): Path<Uuid>,
    Query(query): Query<OneTimeContentQuery>,
) -> AppResult<impl IntoResponse> {
    let delivery = media_once_delivery::Entity::find_by_id(delivery_id)
        .filter(media_once_delivery::Column::RecipientHunterId.eq(claims.sub))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("one-time media delivery not found".into()))?;

    let token = query.token.trim();
    if token.is_empty() {
        return Err(AppError::Unauthorized(
            "missing one-time access token".into(),
        ));
    }
    let provided_hash = hash_once_access_token(token);
    let saved_token = delivery
        .access_token_hash
        .as_ref()
        .ok_or_else(|| AppError::Unauthorized("invalid one-time access token".into()))?;
    if saved_token != &provided_hash {
        return Err(AppError::Forbidden("invalid one-time access token".into()));
    }
    let token_exp = delivery
        .access_token_expires_at
        .ok_or_else(|| AppError::Unauthorized("one-time access token expired".into()))?;
    if token_exp.with_timezone(&Utc) <= Utc::now() {
        return Err(AppError::Unauthorized(
            "one-time access token expired".into(),
        ));
    }

    let media = media_asset::Entity::find_by_id(delivery.media_asset_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("linked media asset not found".into()))?;
    let bytes = read_media_file(&media.storage_key).await?;

    let consumed_at = Utc::now();
    let opened_at = delivery.opened_at.unwrap_or_else(|| consumed_at.into());
    let mut delivery_active = delivery.into_active_model();
    delivery_active.opened_at = Set(Some(opened_at));
    delivery_active.consumed_at = Set(Some(consumed_at.into()));
    delivery_active.remaining_views = Set(0);
    delivery_active.access_token_hash = Set(None);
    delivery_active.access_token_expires_at = Set(None);
    let _ = delivery_active.update(&state.db).await?;

    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(&media.mime_type)
            .unwrap_or_else(|_| HeaderValue::from_static("application/octet-stream")),
    );
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    Ok((headers, Body::from(bytes)))
}

pub async fn get_media_asset_content(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Path(media_id): Path<Uuid>,
) -> AppResult<impl IntoResponse> {
    let media = media_asset::Entity::find_by_id(media_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("media asset not found".into()))?;

    let is_owner = media.owner_hunter_id == claims.sub;
    let has_once_access = if is_owner {
        false
    } else {
        media_once_delivery::Entity::find()
            .filter(media_once_delivery::Column::MediaAssetId.eq(media.id))
            .filter(
                sea_orm::Condition::any()
                    .add(media_once_delivery::Column::RecipientHunterId.eq(claims.sub))
                    .add(media_once_delivery::Column::SenderHunterId.eq(claims.sub)),
            )
            .one(&state.db)
            .await?
            .is_some()
    };
    let has_friend_access = if is_owner || media.mode != "vault" {
        false
    } else {
        friend_link::Entity::find()
            .filter(friend_link::Column::PlayerId.eq(media.owner_hunter_id))
            .filter(friend_link::Column::FriendId.eq(claims.sub))
            .one(&state.db)
            .await?
            .is_some()
    };
    let can_access = is_owner || has_once_access || has_friend_access;
    if !can_access {
        return Err(AppError::Forbidden(
            "not allowed to access this media asset".into(),
        ));
    }

    let bytes = read_media_file(&media.storage_key).await?;
    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(&media.mime_type)
            .unwrap_or_else(|_| HeaderValue::from_static("application/octet-stream")),
    );
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    Ok((headers, Body::from(bytes)))
}

pub async fn create_photo_dump_export(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<CreatePhotoDumpExportRequest>,
) -> AppResult<(StatusCode, Json<PhotoDumpExportResponse>)> {
    let owner_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    if payload.asset_ids.is_empty() {
        return Err(AppError::BadRequest(
            "asset_ids must include at least one media asset".into(),
        ));
    }
    if payload.asset_ids.len() > MAX_EXPORT_ASSET_COUNT {
        return Err(AppError::BadRequest(format!(
            "asset_ids must be <= {MAX_EXPORT_ASSET_COUNT}",
        )));
    }
    let unique_ids: HashSet<Uuid> = payload.asset_ids.iter().copied().collect();
    if unique_ids.len() != payload.asset_ids.len() {
        return Err(AppError::BadRequest(
            "asset_ids must not include duplicates".into(),
        ));
    }

    let rows = media_asset::Entity::find()
        .filter(media_asset::Column::GuildId.eq(claims.guild_id))
        .filter(media_asset::Column::OwnerHunterId.eq(owner_hunter_id))
        .filter(media_asset::Column::Mode.eq("vault"))
        .filter(media_asset::Column::Id.is_in(payload.asset_ids.iter().copied()))
        .all(&state.db)
        .await?;
    if rows.len() != payload.asset_ids.len() {
        return Err(AppError::BadRequest(
            "some asset_ids are not in your vault".into(),
        ));
    }

    let owner = hunter::Entity::find_by_id(owner_hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;
    let style = normalize_export_style(payload.style)?;
    let title = normalize_export_title(payload.title)?;
    let now = Utc::now();
    let id = Uuid::new_v4();

    let export = photo_dump_export::ActiveModel {
        id: Set(id),
        guild_id: Set(claims.guild_id),
        owner_hunter_id: Set(owner_hunter_id),
        title: Set(title),
        style: Set(style),
        asset_count: Set(rows.len() as i32),
        asset_ids_json: Set(serde_json::to_string(&payload.asset_ids).map_err(|err| {
            AppError::ServiceUnavailable(format!("failed to encode export asset ids: {err}"))
        })?),
        created_at: Set(now.into()),
    }
    .insert(&state.db)
    .await?;

    for row in &rows {
        let mut active = row.clone().into_active_model();
        active.is_photo_dump_ready = Set(true);
        let _ = active.update(&state.db).await?;
    }

    let map: HashMap<Uuid, media_asset::Model> =
        rows.into_iter().map(|row| (row.id, row)).collect();
    let assets = payload
        .asset_ids
        .iter()
        .filter_map(|id| map.get(id))
        .map(|row| map_media_asset(row.clone(), &owner.name, &owner.player_id))
        .collect();

    let response = map_photo_dump_export(export, assets);
    Ok((StatusCode::CREATED, Json(response)))
}

pub async fn list_photo_dump_exports(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<MediaListQuery>,
) -> AppResult<Json<Vec<PhotoDumpExportResponse>>> {
    let owner_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let limit = query
        .limit
        .unwrap_or(DEFAULT_MEDIA_LIST_LIMIT)
        .min(MAX_MEDIA_LIST_LIMIT);

    let rows = photo_dump_export::Entity::find()
        .filter(photo_dump_export::Column::GuildId.eq(claims.guild_id))
        .filter(photo_dump_export::Column::OwnerHunterId.eq(owner_hunter_id))
        .order_by_desc(photo_dump_export::Column::CreatedAt)
        .order_by_desc(photo_dump_export::Column::Id)
        .limit(limit)
        .all(&state.db)
        .await?;
    if rows.is_empty() {
        return Ok(Json(Vec::new()));
    }

    let owner = hunter::Entity::find_by_id(owner_hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;

    let mut all_asset_ids = Vec::new();
    let parsed_ids: Vec<Vec<Uuid>> = rows
        .iter()
        .map(|row| {
            let ids = serde_json::from_str::<Vec<Uuid>>(&row.asset_ids_json).unwrap_or_default();
            all_asset_ids.extend(ids.iter().copied());
            ids
        })
        .collect();
    let unique_asset_ids: HashSet<Uuid> = all_asset_ids.into_iter().collect();

    let asset_rows = media_asset::Entity::find()
        .filter(media_asset::Column::GuildId.eq(claims.guild_id))
        .filter(media_asset::Column::OwnerHunterId.eq(owner_hunter_id))
        .filter(media_asset::Column::Id.is_in(unique_asset_ids))
        .all(&state.db)
        .await?;
    let asset_map: HashMap<Uuid, media_asset::Model> =
        asset_rows.into_iter().map(|row| (row.id, row)).collect();

    let response = rows
        .into_iter()
        .zip(parsed_ids)
        .map(|(row, ids)| {
            let assets = ids
                .iter()
                .filter_map(|id| asset_map.get(id))
                .map(|asset| map_media_asset(asset.clone(), &owner.name, &owner.player_id))
                .collect();
            map_photo_dump_export(row, assets)
        })
        .collect();

    Ok(Json(response))
}

#[derive(Debug, Default)]
struct ParsedUploadPayload {
    bytes: Vec<u8>,
    original_filename: Option<String>,
    mime: String,
    caption: Option<String>,
    include_in_dump: Option<bool>,
    recipient_player_id: Option<String>,
    ttl_seconds: Option<i64>,
    encryption_mode: Option<String>,
    protocol_version: Option<String>,
    sender_device_id: Option<String>,
    recipient_device_id: Option<String>,
    encryption_nonce: Option<String>,
    encryption_mac: Option<String>,
}

async fn parse_upload_payload(multipart: &mut Multipart) -> AppResult<ParsedUploadPayload> {
    let mut payload = ParsedUploadPayload::default();

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|err| AppError::BadRequest(format!("invalid multipart payload: {err}")))?
    {
        let name = field.name().unwrap_or_default().to_string();
        if field.file_name().is_some() {
            let original_filename = field.file_name().map(str::to_string);
            let mime = normalize_image_mime(
                field.content_type().map(str::to_string),
                original_filename.as_deref(),
            )?;
            let bytes = field
                .bytes()
                .await
                .map_err(|err| AppError::BadRequest(format!("failed to read upload: {err}")))?;
            if bytes.is_empty() {
                return Err(AppError::BadRequest(
                    "uploaded image must not be empty".into(),
                ));
            }
            if bytes.len() > MAX_MEDIA_BYTE_SIZE {
                return Err(AppError::BadRequest(format!(
                    "uploaded image must be <= {} MB",
                    MAX_MEDIA_BYTE_SIZE / (1024 * 1024)
                )));
            }
            payload.bytes = bytes.to_vec();
            payload.original_filename = original_filename;
            payload.mime = mime;
            continue;
        }

        let value = field
            .text()
            .await
            .map_err(|err| AppError::BadRequest(format!("invalid multipart field: {err}")))?;
        match name.as_str() {
            "caption" => payload.caption = Some(value),
            "include_in_dump" => payload.include_in_dump = Some(parse_bool_field(&value)?),
            "recipient_player_id" => payload.recipient_player_id = Some(value),
            "ttl_seconds" => {
                let parsed = value
                    .trim()
                    .parse::<i64>()
                    .map_err(|_| AppError::BadRequest("ttl_seconds must be an integer".into()))?;
                payload.ttl_seconds = Some(parsed);
            }
            "encryption_mode" => payload.encryption_mode = Some(value),
            "protocol_version" => payload.protocol_version = Some(value),
            "sender_device_id" => payload.sender_device_id = Some(value),
            "recipient_device_id" => payload.recipient_device_id = Some(value),
            "encryption_nonce" => payload.encryption_nonce = Some(value),
            "encryption_mac" => payload.encryption_mac = Some(value),
            _ => {}
        }
    }

    if payload.bytes.is_empty() {
        return Err(AppError::BadRequest(
            "multipart payload must include an image file".into(),
        ));
    }
    if payload.mime.is_empty() {
        return Err(AppError::BadRequest("upload mime type is invalid".into()));
    }
    Ok(payload)
}

fn normalize_caption(raw: Option<String>) -> AppResult<Option<String>> {
    let normalized = raw
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);
    if let Some(value) = normalized.as_deref()
        && value.chars().count() > MAX_MEDIA_CAPTION_CHARS
    {
        return Err(AppError::BadRequest(format!(
            "caption must be <= {MAX_MEDIA_CAPTION_CHARS} characters",
        )));
    }
    Ok(normalized)
}

fn normalize_recipient_player_id(raw: Option<String>) -> AppResult<String> {
    let Some(value) = raw else {
        return Err(AppError::BadRequest(
            "recipient_player_id is required for one-time media".into(),
        ));
    };
    let normalized = value.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return Err(AppError::BadRequest(
            "recipient_player_id must not be empty".into(),
        ));
    }
    if normalized.chars().count() > MAX_RECIPIENT_PLAYER_ID_CHARS {
        return Err(AppError::BadRequest(format!(
            "recipient_player_id must be <= {MAX_RECIPIENT_PLAYER_ID_CHARS} chars",
        )));
    }
    if !normalized
        .chars()
        .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_' || ch == '-')
    {
        return Err(AppError::BadRequest(
            "recipient_player_id contains unsupported characters".into(),
        ));
    }
    Ok(normalized)
}

fn normalize_once_ttl_seconds(raw: Option<i64>) -> AppResult<i64> {
    let ttl = raw.unwrap_or(DEFAULT_ONCE_TTL_SECONDS);
    if !(MIN_ONCE_TTL_SECONDS..=MAX_ONCE_TTL_SECONDS).contains(&ttl) {
        return Err(AppError::BadRequest(format!(
            "ttl_seconds must be between {MIN_ONCE_TTL_SECONDS} and {MAX_ONCE_TTL_SECONDS}",
        )));
    }
    Ok(ttl)
}

#[derive(Debug, Clone)]
struct ParsedMediaEncryption {
    mode: String,
    protocol_version: Option<String>,
    sender_device_id: Option<String>,
    recipient_device_id: Option<String>,
    nonce: Option<String>,
    mac: Option<String>,
}

fn normalize_media_encryption(
    mode: Option<String>,
    protocol_version: Option<String>,
    sender_device_id: Option<String>,
    recipient_device_id: Option<String>,
    nonce: Option<String>,
    mac: Option<String>,
) -> AppResult<ParsedMediaEncryption> {
    let normalized_mode = mode
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(ENCRYPTION_MODE_PLAINTEXT)
        .to_ascii_lowercase();

    let normalized_protocol = normalize_optional_text(
        protocol_version,
        "protocol_version",
        MAX_PROTOCOL_VERSION_CHARS,
    )?;
    let normalized_sender_device =
        normalize_optional_text(sender_device_id, "sender_device_id", MAX_DEVICE_ID_CHARS)?;
    let normalized_recipient_device = normalize_optional_text(
        recipient_device_id,
        "recipient_device_id",
        MAX_DEVICE_ID_CHARS,
    )?;
    let normalized_nonce = normalize_optional_text(nonce, "encryption_nonce", MAX_NONCE_B64_CHARS)?;
    let normalized_mac = normalize_optional_text(mac, "encryption_mac", MAX_MAC_B64_CHARS)?;

    match normalized_mode.as_str() {
        ENCRYPTION_MODE_PLAINTEXT => {
            if normalized_protocol.is_some()
                || normalized_sender_device.is_some()
                || normalized_recipient_device.is_some()
                || normalized_nonce.is_some()
                || normalized_mac.is_some()
            {
                return Err(AppError::BadRequest(
                    "plaintext media must not include encryption metadata".into(),
                ));
            }
            Ok(ParsedMediaEncryption {
                mode: ENCRYPTION_MODE_PLAINTEXT.to_string(),
                protocol_version: None,
                sender_device_id: None,
                recipient_device_id: None,
                nonce: None,
                mac: None,
            })
        }
        ENCRYPTION_MODE_E2EE => {
            let protocol_version = normalized_protocol
                .ok_or_else(|| AppError::BadRequest("protocol_version is required".into()))?;
            let sender_device_id = normalized_sender_device
                .ok_or_else(|| AppError::BadRequest("sender_device_id is required".into()))?;
            let recipient_device_id = normalized_recipient_device
                .ok_or_else(|| AppError::BadRequest("recipient_device_id is required".into()))?;
            let nonce = normalized_nonce
                .ok_or_else(|| AppError::BadRequest("encryption_nonce is required".into()))?;
            let mac = normalized_mac
                .ok_or_else(|| AppError::BadRequest("encryption_mac is required".into()))?;

            if !protocol_version.starts_with("dm-e2ee-v") {
                return Err(AppError::BadRequest(
                    "protocol_version is not supported".into(),
                ));
            }
            decode_base64_field(&nonce, "encryption_nonce")?;
            decode_base64_field(&mac, "encryption_mac")?;

            Ok(ParsedMediaEncryption {
                mode: ENCRYPTION_MODE_E2EE.to_string(),
                protocol_version: Some(protocol_version),
                sender_device_id: Some(sender_device_id),
                recipient_device_id: Some(recipient_device_id),
                nonce: Some(nonce),
                mac: Some(mac),
            })
        }
        _ => Err(AppError::BadRequest(
            "encryption_mode must be plaintext or e2ee".into(),
        )),
    }
}

fn normalize_optional_text(
    raw: Option<String>,
    field_name: &str,
    max_chars: usize,
) -> AppResult<Option<String>> {
    let normalized = raw
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);
    if let Some(value) = normalized.as_deref()
        && value.chars().count() > max_chars
    {
        return Err(AppError::BadRequest(format!(
            "{field_name} must be <= {max_chars} characters",
        )));
    }
    Ok(normalized)
}

fn decode_base64_field(value: &str, field_name: &str) -> AppResult<Vec<u8>> {
    use base64::{Engine as _, engine::general_purpose::STANDARD};
    STANDARD
        .decode(value)
        .map_err(|_| AppError::BadRequest(format!("{field_name} must be valid base64")))
}

fn parse_bool_field(raw: &str) -> AppResult<bool> {
    let normalized = raw.trim().to_ascii_lowercase();
    match normalized.as_str() {
        "1" | "true" | "yes" | "on" => Ok(true),
        "0" | "false" | "no" | "off" => Ok(false),
        _ => Err(AppError::BadRequest(format!(
            "invalid boolean value: {raw}",
        ))),
    }
}

fn normalize_export_style(raw: Option<String>) -> AppResult<String> {
    let style = raw
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or("retro")
        .to_ascii_lowercase();
    if !matches!(style.as_str(), "retro" | "lockit" | "classic") {
        return Err(AppError::BadRequest(
            "style must be one of retro, lockit, classic".into(),
        ));
    }
    Ok(style)
}

fn normalize_export_title(raw: Option<String>) -> AppResult<String> {
    let title = raw
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| format!("Photo Dump {}", Utc::now().format("%Y-%m-%d")));
    if title.chars().count() > 120 {
        return Err(AppError::BadRequest("title must be <= 120 chars".into()));
    }
    Ok(title)
}

fn normalize_image_mime(content_type: Option<String>, filename: Option<&str>) -> AppResult<String> {
    if let Some(raw) = content_type {
        let normalized = raw.trim().to_ascii_lowercase();
        if is_supported_image_mime(&normalized) {
            return Ok(normalized);
        }
    }
    if let Some(name) = filename
        && let Some(inferred) = infer_mime_from_filename(name)
    {
        return Ok(inferred);
    }
    Err(AppError::BadRequest(
        "only image uploads are supported (jpeg/png/webp/heic)".into(),
    ))
}

fn is_supported_image_mime(value: &str) -> bool {
    matches!(
        value,
        "image/jpeg" | "image/jpg" | "image/png" | "image/webp" | "image/heic" | "image/heif"
    )
}

fn infer_mime_from_filename(filename: &str) -> Option<String> {
    let lower = filename.to_ascii_lowercase();
    if lower.ends_with(".jpg") || lower.ends_with(".jpeg") {
        return Some("image/jpeg".to_string());
    }
    if lower.ends_with(".png") {
        return Some("image/png".to_string());
    }
    if lower.ends_with(".webp") {
        return Some("image/webp".to_string());
    }
    if lower.ends_with(".heic") {
        return Some("image/heic".to_string());
    }
    if lower.ends_with(".heif") {
        return Some("image/heif".to_string());
    }
    None
}

fn preferred_media_extension(filename: Option<&str>, mime: &str) -> &'static str {
    if let Some(name) = filename {
        let lower = name.to_ascii_lowercase();
        if lower.ends_with(".jpg") || lower.ends_with(".jpeg") {
            return ".jpg";
        }
        if lower.ends_with(".png") {
            return ".png";
        }
        if lower.ends_with(".webp") {
            return ".webp";
        }
        if lower.ends_with(".heic") {
            return ".heic";
        }
        if lower.ends_with(".heif") {
            return ".heif";
        }
    }
    match mime {
        "image/png" => ".png",
        "image/webp" => ".webp",
        "image/heic" => ".heic",
        "image/heif" => ".heif",
        _ => ".jpg",
    }
}

async fn ensure_friendship(
    state: &AppState,
    sender_hunter_id: Uuid,
    recipient_hunter_id: Uuid,
) -> AppResult<()> {
    let linked = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(sender_hunter_id))
        .filter(friend_link::Column::FriendId.eq(recipient_hunter_id))
        .one(&state.db)
        .await?
        .is_some();
    if linked {
        return Ok(());
    }
    Err(AppError::Forbidden(
        "one-time media can only be sent to friends".into(),
    ))
}

async fn require_active_dm_device_key(
    state: &AppState,
    hunter_id: Uuid,
    device_id: &str,
) -> AppResult<dm_device_key::Model> {
    dm_device_key::Entity::find()
        .filter(dm_device_key::Column::HunterId.eq(hunter_id))
        .filter(dm_device_key::Column::DeviceId.eq(device_id.to_string()))
        .filter(dm_device_key::Column::RevokedAt.is_null())
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::BadRequest(format!("active device key not found for {device_id}")))
}

fn media_upload_root() -> PathBuf {
    std::env::var("MEDIA_UPLOAD_ROOT")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("output/uploads"))
}

async fn persist_media_file(storage_key: &str, bytes: &[u8]) -> AppResult<()> {
    let path = media_upload_root().join(storage_key);
    if let Some(parent) = path.parent() {
        tokio::fs::create_dir_all(parent).await.map_err(|err| {
            AppError::ServiceUnavailable(format!("failed to prepare upload directory: {err}"))
        })?;
    }
    tokio::fs::write(path, bytes).await.map_err(|err| {
        AppError::ServiceUnavailable(format!("failed to store uploaded media: {err}"))
    })
}

async fn read_media_file(storage_key: &str) -> AppResult<Vec<u8>> {
    let path = media_upload_root().join(storage_key);
    tokio::fs::read(path)
        .await
        .map_err(|_| AppError::NotFound("media content not found".into()))
}

fn build_once_access_token() -> String {
    format!(
        "{}_{}_{}",
        ONCE_OPEN_TOKEN_PREFIX,
        Uuid::new_v4().simple(),
        Uuid::new_v4().simple()
    )
}

fn hash_once_access_token(token: &str) -> String {
    use base64::{Engine as _, engine::general_purpose::STANDARD_NO_PAD};
    let digest = Sha256::digest(token.as_bytes());
    STANDARD_NO_PAD.encode(digest)
}

fn map_media_asset(
    model: media_asset::Model,
    owner_name: &str,
    owner_player_id: &str,
) -> MediaAssetResponse {
    MediaAssetResponse {
        id: model.id,
        guild_id: model.guild_id,
        owner_hunter_id: model.owner_hunter_id,
        owner_name: owner_name.to_string(),
        owner_player_id: owner_player_id.to_string(),
        mode: model.mode,
        original_filename: model.original_filename,
        mime_type: model.mime_type,
        byte_size: model.byte_size,
        caption: model.caption,
        is_photo_dump_ready: model.is_photo_dump_ready,
        created_at: model.created_at.with_timezone(&Utc),
        expires_at: model.expires_at.map(|value| value.with_timezone(&Utc)),
        content_path: format!("/api/v1/media/assets/{}/content", model.id),
    }
}

fn map_once_delivery(
    delivery: media_once_delivery::Model,
    media: media_asset::Model,
    sender_name: &str,
    sender_player_id: &str,
) -> MediaOnceDeliveryResponse {
    MediaOnceDeliveryResponse {
        id: delivery.id,
        media_asset_id: delivery.media_asset_id,
        guild_id: delivery.guild_id,
        sender_hunter_id: delivery.sender_hunter_id,
        sender_name: sender_name.to_string(),
        sender_player_id: sender_player_id.to_string(),
        recipient_hunter_id: delivery.recipient_hunter_id,
        caption: media.caption,
        mime_type: media.mime_type,
        created_at: delivery.created_at.with_timezone(&Utc),
        expires_at: delivery.expires_at.map(|value| value.with_timezone(&Utc)),
        opened_at: delivery.opened_at.map(|value| value.with_timezone(&Utc)),
        consumed_at: delivery.consumed_at.map(|value| value.with_timezone(&Utc)),
        remaining_views: delivery.remaining_views,
        encryption: map_media_encryption_snapshot(&delivery),
    }
}

fn map_media_encryption_snapshot(delivery: &media_once_delivery::Model) -> MediaEncryptionSnapshot {
    MediaEncryptionSnapshot {
        mode: delivery.encryption_mode.clone(),
        protocol_version: delivery.protocol_version.clone(),
        sender_device_id: delivery.sender_device_id.clone(),
        recipient_device_id: delivery.recipient_device_id.clone(),
        nonce: delivery.encryption_nonce.clone(),
        mac: delivery.encryption_mac.clone(),
    }
}

fn map_photo_dump_export(
    model: photo_dump_export::Model,
    assets: Vec<MediaAssetResponse>,
) -> PhotoDumpExportResponse {
    PhotoDumpExportResponse {
        id: model.id,
        guild_id: model.guild_id,
        owner_hunter_id: model.owner_hunter_id,
        title: model.title,
        style: model.style,
        asset_count: model.asset_count,
        created_at: model.created_at.with_timezone(&Utc),
        assets,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_recipient_player_id_accepts_and_normalizes() {
        let value = normalize_recipient_player_id(Some("  Demo_User-01  ".to_string()))
            .expect("recipient id should normalize");
        assert_eq!(value, "demo_user-01");
    }

    #[test]
    fn normalize_recipient_player_id_rejects_invalid_chars() {
        let result = normalize_recipient_player_id(Some("demo@user".to_string()));
        assert!(result.is_err());
    }

    #[test]
    fn normalize_once_ttl_seconds_defaults_and_bounds() {
        let default_ttl = normalize_once_ttl_seconds(None).expect("default ttl");
        assert_eq!(default_ttl, DEFAULT_ONCE_TTL_SECONDS);

        assert_eq!(
            normalize_once_ttl_seconds(Some(MIN_ONCE_TTL_SECONDS)).expect("min ttl"),
            MIN_ONCE_TTL_SECONDS
        );
        assert_eq!(
            normalize_once_ttl_seconds(Some(MAX_ONCE_TTL_SECONDS)).expect("max ttl"),
            MAX_ONCE_TTL_SECONDS
        );
        assert!(normalize_once_ttl_seconds(Some(MIN_ONCE_TTL_SECONDS - 1)).is_err());
        assert!(normalize_once_ttl_seconds(Some(MAX_ONCE_TTL_SECONDS + 1)).is_err());
    }

    #[test]
    fn normalize_export_style_validates_known_values() {
        assert_eq!(
            normalize_export_style(Some(" RETRO ".to_string())).expect("retro style"),
            "retro"
        );
        assert_eq!(
            normalize_export_style(Some("lockit".to_string())).expect("lockit style"),
            "lockit"
        );
        assert!(normalize_export_style(Some("unknown".to_string())).is_err());
    }

    #[test]
    fn normalize_image_mime_supports_content_type_and_filename() {
        let by_header =
            normalize_image_mime(Some("image/png".to_string()), None).expect("png by content-type");
        assert_eq!(by_header, "image/png");

        let by_file = normalize_image_mime(None, Some("memory.HEIC")).expect("heic by filename");
        assert_eq!(by_file, "image/heic");

        assert!(normalize_image_mime(Some("text/plain".to_string()), Some("note.txt")).is_err());
    }

    #[test]
    fn normalize_media_encryption_validates_mode_and_required_fields() {
        let plain = normalize_media_encryption(None, None, None, None, None, None)
            .expect("plaintext defaults should be valid");
        assert_eq!(plain.mode, ENCRYPTION_MODE_PLAINTEXT);

        let encrypted = normalize_media_encryption(
            Some(ENCRYPTION_MODE_E2EE.to_string()),
            Some("dm-e2ee-v1".to_string()),
            Some("sender-device".to_string()),
            Some("recipient-device".to_string()),
            Some("AQIDBA==".to_string()),
            Some("BQQDAgE=".to_string()),
        )
        .expect("valid e2ee metadata");
        assert_eq!(encrypted.mode, ENCRYPTION_MODE_E2EE);
        assert_eq!(encrypted.protocol_version.as_deref(), Some("dm-e2ee-v1"));

        assert!(
            normalize_media_encryption(
                Some(ENCRYPTION_MODE_PLAINTEXT.to_string()),
                Some("dm-e2ee-v1".to_string()),
                None,
                None,
                None,
                None
            )
            .is_err()
        );
        assert!(
            normalize_media_encryption(
                Some(ENCRYPTION_MODE_E2EE.to_string()),
                Some("dm-e2ee-v1".to_string()),
                Some("sender-device".to_string()),
                Some("recipient-device".to_string()),
                Some("!not-base64!".to_string()),
                Some("BQQDAgE=".to_string())
            )
            .is_err()
        );
    }

    #[test]
    fn once_access_token_hash_is_stable_and_not_plaintext() {
        let token = "once_token_demo";
        let hash = hash_once_access_token(token);
        assert_ne!(hash, token);
        assert_eq!(hash, hash_once_access_token(token));
    }
}
