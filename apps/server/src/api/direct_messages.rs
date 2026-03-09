use std::collections::{HashMap, HashSet};

use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
};
use chrono::{TimeZone, Utc};
use entity::{
    direct_message, dm_conversation_capability, dm_conversation_capability::DmEncryptionMode,
    dm_device_key, dm_encrypted_message, dm_thread_read, friend_link, hunter,
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, Condition, ConnectionTrait, DbErr,
    EntityTrait, IntoActiveModel, QueryFilter, QueryOrder, QuerySelect, Statement, Value,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::HunterClaims,
    state::AppState,
};

const DEFAULT_HISTORY_LIMIT: u64 = 50;
const MAX_HISTORY_LIMIT: u64 = 200;
const DEFAULT_THREAD_LIMIT: u64 = 40;
const MAX_DM_CONTENT_LEN: usize = 480;
const MAX_DM_DEVICE_ID_LEN: usize = 96;
const MAX_DM_DEVICE_LABEL_LEN: usize = 120;
const MAX_DM_PUBLIC_KEY_LEN: usize = 8192;
const MAX_DM_PROTOCOL_VERSION_LEN: usize = 24;
const MAX_DM_NONCE_LEN: usize = 255;
const MAX_DM_CIPHERTEXT_LEN: usize = 128 * 1024;

#[derive(Debug, Deserialize)]
pub struct PersistDirectMessageRequest {
    pub recipient_hunter_id: Uuid,
    pub client_message_id: Option<Uuid>,
    pub content: String,
    pub sent_at_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct DirectMessageHistoryQuery {
    pub counterpart_hunter_id: Uuid,
    pub limit: Option<u64>,
    pub before_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct DirectMessageThreadsQuery {
    pub limit: Option<u64>,
}

#[derive(Debug, Deserialize)]
pub struct RegisterDmDeviceKeyRequest {
    pub device_id: String,
    pub device_label: Option<String>,
    pub signing_public_key: String,
    pub encryption_public_key: String,
}

#[derive(Debug, Deserialize)]
pub struct RevokeDmDeviceKeyRequest {
    pub device_id: String,
}

#[derive(Debug, Deserialize)]
pub struct BatchDmDeviceKeysQuery {
    pub hunter_ids: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct PersistEncryptedDirectMessageRequest {
    pub recipient_hunter_id: Uuid,
    pub sender_device_id: String,
    pub recipient_device_id: String,
    pub client_message_id: Option<Uuid>,
    pub protocol_version: Option<String>,
    pub ciphertext: String,
    pub nonce: String,
    pub sent_at_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct EncryptedDirectMessageHistoryQuery {
    pub counterpart_hunter_id: Uuid,
    pub limit: Option<u64>,
    pub before_ms: Option<i64>,
}

#[derive(Debug, Serialize, Clone)]
pub struct DirectMessageResponse {
    pub id: Uuid,
    pub sender_hunter_id: Uuid,
    pub recipient_hunter_id: Uuid,
    pub counterpart_hunter_id: Uuid,
    pub counterpart_name: String,
    pub counterpart_player_id: String,
    pub counterpart_guild_id: Uuid,
    pub sender_name: String,
    pub client_message_id: Uuid,
    pub content: String,
    pub sent_at: chrono::DateTime<chrono::Utc>,
    pub sent_at_ms: i64,
}

#[derive(Debug, Serialize, Clone)]
pub struct DirectMessageThreadResponse {
    pub conversation_key: String,
    pub counterpart_hunter_id: Uuid,
    pub counterpart_name: String,
    pub counterpart_player_id: String,
    pub counterpart_guild_id: Uuid,
    pub counterpart_avatar_type: String,
    pub last_message: String,
    pub last_message_sender_hunter_id: Uuid,
    pub last_message_sender_name: String,
    pub last_message_at: chrono::DateTime<chrono::Utc>,
    pub last_message_at_ms: i64,
    pub encryption_mode: DmEncryptionMode,
    pub unread_count: u64,
}

#[derive(Debug, Serialize, Clone)]
pub struct DmThreadReadResponse {
    pub counterpart_hunter_id: Uuid,
    pub conversation_key: String,
    pub last_read_at: chrono::DateTime<chrono::Utc>,
    pub last_read_at_ms: i64,
    pub unread_count: u64,
}

#[derive(Debug, Serialize, Clone)]
pub struct DmDeviceKeyResponse {
    pub id: Uuid,
    pub hunter_id: Uuid,
    pub device_id: String,
    pub device_label: Option<String>,
    pub signing_public_key: String,
    pub encryption_public_key: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub last_seen_at: chrono::DateTime<chrono::Utc>,
    pub revoked_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Serialize, Clone)]
pub struct DmDeviceKeyBatchResponse {
    pub hunter_id: Uuid,
    pub keys: Vec<DmDeviceKeyResponse>,
}

#[derive(Debug, Serialize, Clone)]
pub struct EncryptedDirectMessageResponse {
    pub id: Uuid,
    pub sender_hunter_id: Uuid,
    pub recipient_hunter_id: Uuid,
    pub counterpart_hunter_id: Uuid,
    pub counterpart_name: String,
    pub counterpart_player_id: String,
    pub counterpart_guild_id: Uuid,
    pub sender_device_id: String,
    pub recipient_device_id: String,
    pub client_message_id: Uuid,
    pub protocol_version: String,
    pub ciphertext: String,
    pub nonce: String,
    pub sent_at: chrono::DateTime<chrono::Utc>,
    pub sent_at_ms: i64,
    pub encryption_mode: DmEncryptionMode,
}

pub async fn register_dm_device_key(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<RegisterDmDeviceKeyRequest>,
) -> AppResult<(StatusCode, Json<DmDeviceKeyResponse>)> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let device_id = normalize_device_id(&payload.device_id)?;
    let device_label = normalize_optional_trimmed(payload.device_label, MAX_DM_DEVICE_LABEL_LEN)?;
    let signing_public_key = normalize_required_text(
        "signing_public_key",
        &payload.signing_public_key,
        MAX_DM_PUBLIC_KEY_LEN,
    )?;
    let encryption_public_key = normalize_required_text(
        "encryption_public_key",
        &payload.encryption_public_key,
        MAX_DM_PUBLIC_KEY_LEN,
    )?;

    let now = Utc::now();
    let existing = dm_device_key::Entity::find()
        .filter(dm_device_key::Column::HunterId.eq(hunter_id))
        .filter(dm_device_key::Column::DeviceId.eq(device_id.clone()))
        .one(&state.db)
        .await?;

    let model = if let Some(existing) = existing {
        let mut active = existing.into_active_model();
        active.device_label = Set(device_label.clone());
        active.signing_public_key = Set(signing_public_key.clone());
        active.encryption_public_key = Set(encryption_public_key.clone());
        active.last_seen_at = Set(now.into());
        active.revoked_at = Set(None);
        active.update(&state.db).await?
    } else {
        dm_device_key::ActiveModel {
            id: Set(Uuid::new_v4()),
            hunter_id: Set(hunter_id),
            device_id: Set(device_id),
            device_label: Set(device_label),
            signing_public_key: Set(signing_public_key),
            encryption_public_key: Set(encryption_public_key),
            created_at: Set(now.into()),
            last_seen_at: Set(now.into()),
            revoked_at: Set(None),
        }
        .insert(&state.db)
        .await?
    };

    Ok((StatusCode::OK, Json(map_dm_device_key(&model))))
}

pub async fn list_dm_device_keys(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(hunter_id): Path<Uuid>,
) -> AppResult<Json<Vec<DmDeviceKeyResponse>>> {
    let requester_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    ensure_dm_device_key_access(&state, requester_id, hunter_id).await?;

    let rows = dm_device_key::Entity::find()
        .filter(dm_device_key::Column::HunterId.eq(hunter_id))
        .filter(dm_device_key::Column::RevokedAt.is_null())
        .order_by_asc(dm_device_key::Column::CreatedAt)
        .all(&state.db)
        .await?;

    Ok(Json(rows.iter().map(map_dm_device_key).collect()))
}

pub async fn list_dm_device_keys_batch(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<BatchDmDeviceKeysQuery>,
) -> AppResult<Json<Vec<DmDeviceKeyBatchResponse>>> {
    let requester_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let requested_ids = parse_batch_hunter_ids(query.hunter_ids)?;
    if requested_ids.is_empty() {
        return Ok(Json(Vec::new()));
    }

    for hunter_id in &requested_ids {
        ensure_dm_device_key_access(&state, requester_id, *hunter_id).await?;
    }

    let rows = dm_device_key::Entity::find()
        .filter(dm_device_key::Column::HunterId.is_in(requested_ids.iter().copied()))
        .filter(dm_device_key::Column::RevokedAt.is_null())
        .order_by_asc(dm_device_key::Column::HunterId)
        .order_by_asc(dm_device_key::Column::CreatedAt)
        .all(&state.db)
        .await?;

    let mut grouped: HashMap<Uuid, Vec<DmDeviceKeyResponse>> = HashMap::new();
    for row in rows {
        grouped
            .entry(row.hunter_id)
            .or_default()
            .push(map_dm_device_key(&row));
    }

    let payload = requested_ids
        .into_iter()
        .map(|hunter_id| DmDeviceKeyBatchResponse {
            hunter_id,
            keys: grouped.remove(&hunter_id).unwrap_or_default(),
        })
        .collect::<Vec<_>>();

    Ok(Json(payload))
}

pub async fn revoke_dm_device_key(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<RevokeDmDeviceKeyRequest>,
) -> AppResult<Json<DmDeviceKeyResponse>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let device_id = normalize_device_id(&payload.device_id)?;

    let existing = dm_device_key::Entity::find()
        .filter(dm_device_key::Column::HunterId.eq(hunter_id))
        .filter(dm_device_key::Column::DeviceId.eq(device_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("device key not found".into()))?;

    let mut active = existing.into_active_model();
    active.revoked_at = Set(Some(Utc::now().into()));
    active.last_seen_at = Set(Utc::now().into());
    let updated = active.update(&state.db).await?;

    Ok(Json(map_dm_device_key(&updated)))
}

pub async fn persist_direct_message(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<PersistDirectMessageRequest>,
) -> AppResult<(StatusCode, Json<DirectMessageResponse>)> {
    let sender_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    if payload.recipient_hunter_id == sender_hunter_id {
        return Err(AppError::BadRequest(
            "cannot send a direct message to yourself".into(),
        ));
    }

    let content = payload.content.trim();
    if content.is_empty() {
        return Err(AppError::BadRequest("content must not be empty".into()));
    }
    if content.chars().count() > MAX_DM_CONTENT_LEN {
        return Err(AppError::BadRequest(format!(
            "content too long, max {} characters",
            MAX_DM_CONTENT_LEN
        )));
    }

    let sender = hunter::Entity::find_by_id(sender_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid sender hunter".into()))?;
    let recipient = hunter::Entity::find_by_id(payload.recipient_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("recipient hunter not found".into()))?;
    ensure_friend_link(&state, sender.id, recipient.id).await?;

    let conversation_key = conversation_key(sender.id, recipient.id);
    let client_message_id = payload.client_message_id.unwrap_or_else(Uuid::new_v4);
    let sent_at = payload
        .sent_at_ms
        .and_then(|ms| Utc.timestamp_millis_opt(ms).single())
        .unwrap_or_else(Utc::now);

    let model = match (direct_message::ActiveModel {
        id: Set(Uuid::new_v4()),
        sender_hunter_id: Set(sender.id),
        recipient_hunter_id: Set(recipient.id),
        conversation_key: Set(conversation_key.clone()),
        client_message_id: Set(client_message_id),
        content: Set(content.to_string()),
        sent_at: Set(sent_at.into()),
    }
    .insert(&state.db)
    .await)
    {
        Ok(model) => model,
        Err(err) => {
            if !is_dm_dedupe_violation(&err) {
                return Err(err.into());
            }
            direct_message::Entity::find()
                .filter(direct_message::Column::ConversationKey.eq(conversation_key.clone()))
                .filter(direct_message::Column::ClientMessageId.eq(client_message_id))
                .one(&state.db)
                .await?
                .ok_or_else(|| {
                    AppError::Conflict(
                        "message dedupe conflict detected but existing row not found".into(),
                    )
                })?
        }
    };

    let counterpart_hunter_id = if model.sender_hunter_id == sender.id {
        model.recipient_hunter_id
    } else {
        model.sender_hunter_id
    };
    let counterpart = if counterpart_hunter_id == recipient.id {
        recipient
    } else {
        sender.clone()
    };

    Ok((
        StatusCode::OK,
        Json(map_direct_message(&model, &sender, &counterpart)),
    ))
}

pub async fn list_direct_message_history(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<DirectMessageHistoryQuery>,
) -> AppResult<Json<Vec<DirectMessageResponse>>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let me = hunter::Entity::find_by_id(my_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid hunter identity".into()))?;
    let counterpart = hunter::Entity::find_by_id(query.counterpart_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("counterpart hunter not found".into()))?;
    ensure_friend_link(&state, me.id, counterpart.id).await?;

    let conversation_key = conversation_key(me.id, counterpart.id);
    let limit = query
        .limit
        .unwrap_or(DEFAULT_HISTORY_LIMIT)
        .min(MAX_HISTORY_LIMIT);

    let mut finder = direct_message::Entity::find()
        .filter(direct_message::Column::ConversationKey.eq(conversation_key))
        .order_by_desc(direct_message::Column::SentAt)
        .order_by_desc(direct_message::Column::Id);

    if let Some(before_ms) = query.before_ms {
        let before = Utc
            .timestamp_millis_opt(before_ms)
            .single()
            .ok_or_else(|| AppError::BadRequest("invalid before_ms".into()))?;
        finder = finder.filter(direct_message::Column::SentAt.lt(before));
    }

    let mut rows = finder.limit(limit).all(&state.db).await?;
    rows.reverse();

    let messages = rows
        .iter()
        .map(|row| {
            let sender_model = if row.sender_hunter_id == me.id {
                &me
            } else {
                &counterpart
            };
            let counterpart_model = if row.sender_hunter_id == me.id {
                &counterpart
            } else {
                &me
            };
            map_direct_message(row, sender_model, counterpart_model)
        })
        .collect();

    Ok(Json(messages))
}

pub async fn list_direct_message_threads(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<DirectMessageThreadsQuery>,
) -> AppResult<Json<Vec<DirectMessageThreadResponse>>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let limit = query
        .limit
        .unwrap_or(DEFAULT_THREAD_LIMIT)
        .min(MAX_HISTORY_LIMIT);
    let mut latest_rows = if state.db.get_database_backend() == sea_orm::DatabaseBackend::Postgres {
        load_latest_thread_candidates(&state, my_hunter_id, limit).await?
    } else {
        load_latest_thread_candidates_fallback(&state, my_hunter_id, limit).await?
    };
    if latest_rows.is_empty() {
        return Ok(Json(Vec::new()));
    }
    latest_rows.truncate(limit as usize);

    let mut conversation_key_seen = HashSet::new();
    let mut conversation_keys = Vec::with_capacity(latest_rows.len());
    let mut hunter_ids = HashSet::new();
    for row in &latest_rows {
        if conversation_key_seen.insert(row.conversation_key.clone()) {
            conversation_keys.push(row.conversation_key.clone());
        }
        hunter_ids.insert(row.sender_hunter_id);
        hunter_ids.insert(if row.sender_hunter_id == my_hunter_id {
            row.recipient_hunter_id
        } else {
            row.sender_hunter_id
        });
    }

    let hunter_map = if hunter_ids.is_empty() {
        HashMap::new()
    } else {
        hunter::Entity::find()
            .filter(hunter::Column::Id.is_in(hunter_ids))
            .all(&state.db)
            .await?
            .into_iter()
            .map(|hunter| (hunter.id, hunter))
            .collect::<HashMap<_, _>>()
    };
    let capability_map = if conversation_keys.is_empty() {
        HashMap::new()
    } else {
        dm_conversation_capability::Entity::find()
            .filter(
                dm_conversation_capability::Column::ConversationKey
                    .is_in(conversation_keys.iter().cloned()),
            )
            .all(&state.db)
            .await?
            .into_iter()
            .map(|row| (row.conversation_key.clone(), row))
            .collect::<HashMap<_, _>>()
    };
    let unread_by_conversation =
        load_unread_counts_for_threads(&state, my_hunter_id, &conversation_keys).await?;

    let mut threads = Vec::new();
    for row in &latest_rows {
        let counterpart_id = if row.sender_hunter_id == my_hunter_id {
            row.recipient_hunter_id
        } else {
            row.sender_hunter_id
        };
        let Some(counterpart) = hunter_map.get(&counterpart_id) else {
            continue;
        };
        let Some(sender) = hunter_map.get(&row.sender_hunter_id) else {
            continue;
        };
        let encryption_mode = capability_map
            .get(&row.conversation_key)
            .map(|cap| cap.encryption_mode.clone())
            .unwrap_or_else(|| row.encryption_mode.clone());
        let unread_count = unread_by_conversation
            .get(&row.conversation_key)
            .copied()
            .unwrap_or(0);
        threads.push(map_thread_candidate(
            row,
            counterpart,
            sender,
            encryption_mode,
            unread_count,
        ));
    }

    threads.sort_by(|a, b| b.last_message_at.cmp(&a.last_message_at));
    Ok(Json(threads))
}

pub async fn mark_direct_message_thread_read(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(counterpart_hunter_id): Path<Uuid>,
) -> AppResult<Json<DmThreadReadResponse>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    if hunter_id == counterpart_hunter_id {
        return Err(AppError::BadRequest(
            "cannot mark a self thread as read".into(),
        ));
    }

    let requester = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid hunter identity".into()))?;
    let counterpart = hunter::Entity::find_by_id(counterpart_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("counterpart hunter not found".into()))?;
    ensure_friend_link(&state, requester.id, counterpart.id).await?;

    let conversation_key = conversation_key(requester.id, counterpart.id);
    let now = Utc::now();
    let last_read_at = latest_message_timestamp_for_conversation(&state, &conversation_key)
        .await?
        .unwrap_or(now);

    let existing = dm_thread_read::Entity::find()
        .filter(dm_thread_read::Column::HunterId.eq(requester.id))
        .filter(dm_thread_read::Column::ConversationKey.eq(conversation_key.clone()))
        .one(&state.db)
        .await?;

    let updated = if let Some(existing) = existing {
        let mut active = existing.into_active_model();
        active.last_read_at = Set(last_read_at.into());
        active.updated_at = Set(now.into());
        active.update(&state.db).await?
    } else {
        dm_thread_read::ActiveModel {
            id: Set(Uuid::new_v4()),
            hunter_id: Set(requester.id),
            conversation_key: Set(conversation_key.clone()),
            last_read_at: Set(last_read_at.into()),
            updated_at: Set(now.into()),
        }
        .insert(&state.db)
        .await?
    };

    Ok(Json(DmThreadReadResponse {
        counterpart_hunter_id,
        conversation_key,
        last_read_at: updated.last_read_at.with_timezone(&Utc),
        last_read_at_ms: updated.last_read_at.with_timezone(&Utc).timestamp_millis(),
        unread_count: 0,
    }))
}

pub async fn persist_encrypted_direct_message(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<PersistEncryptedDirectMessageRequest>,
) -> AppResult<(StatusCode, Json<EncryptedDirectMessageResponse>)> {
    let sender_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    if payload.recipient_hunter_id == sender_hunter_id {
        return Err(AppError::BadRequest(
            "cannot send an encrypted direct message to yourself".into(),
        ));
    }

    let sender_device_id = normalize_device_id(&payload.sender_device_id)?;
    let recipient_device_id = normalize_device_id(&payload.recipient_device_id)?;
    let protocol_version = normalize_protocol_version(payload.protocol_version)?;
    let ciphertext =
        normalize_required_text("ciphertext", &payload.ciphertext, MAX_DM_CIPHERTEXT_LEN)?;
    let nonce = normalize_required_text("nonce", &payload.nonce, MAX_DM_NONCE_LEN)?;

    let sender = hunter::Entity::find_by_id(sender_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid sender hunter".into()))?;
    let recipient = hunter::Entity::find_by_id(payload.recipient_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("recipient hunter not found".into()))?;
    ensure_friend_link(&state, sender.id, recipient.id).await?;

    let _sender_device = require_active_dm_device_key(&state, sender.id, &sender_device_id).await?;
    let _recipient_device =
        require_active_dm_device_key(&state, recipient.id, &recipient_device_id).await?;

    let conversation_key = conversation_key(sender.id, recipient.id);
    let client_message_id = payload.client_message_id.unwrap_or_else(Uuid::new_v4);
    let sent_at = payload
        .sent_at_ms
        .and_then(|ms| Utc.timestamp_millis_opt(ms).single())
        .unwrap_or_else(Utc::now);

    let model = match (dm_encrypted_message::ActiveModel {
        id: Set(Uuid::new_v4()),
        sender_hunter_id: Set(sender.id),
        recipient_hunter_id: Set(recipient.id),
        conversation_key: Set(conversation_key.clone()),
        sender_device_id: Set(sender_device_id),
        recipient_device_id: Set(recipient_device_id),
        client_message_id: Set(client_message_id),
        protocol_version: Set(protocol_version),
        ciphertext: Set(ciphertext),
        nonce: Set(nonce),
        sent_at: Set(sent_at.into()),
    }
    .insert(&state.db)
    .await)
    {
        Ok(model) => model,
        Err(err) => {
            if !is_encrypted_dm_dedupe_violation(&err) {
                return Err(err.into());
            }
            dm_encrypted_message::Entity::find()
                .filter(dm_encrypted_message::Column::ConversationKey.eq(conversation_key.clone()))
                .filter(dm_encrypted_message::Column::ClientMessageId.eq(client_message_id))
                .one(&state.db)
                .await?
                .ok_or_else(|| {
                    AppError::Conflict(
                        "encrypted message dedupe conflict detected but existing row not found"
                            .into(),
                    )
                })?
        }
    };

    upsert_dm_conversation_capability(&state, sender.id, recipient.id, &conversation_key).await?;

    let counterpart_hunter_id = if model.sender_hunter_id == sender.id {
        model.recipient_hunter_id
    } else {
        model.sender_hunter_id
    };
    let counterpart = if counterpart_hunter_id == recipient.id {
        recipient
    } else {
        sender.clone()
    };

    Ok((
        StatusCode::OK,
        Json(map_encrypted_direct_message(
            &model,
            &counterpart,
            DmEncryptionMode::Encrypted,
        )),
    ))
}

pub async fn list_encrypted_direct_message_history(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Query(query): Query<EncryptedDirectMessageHistoryQuery>,
) -> AppResult<Json<Vec<EncryptedDirectMessageResponse>>> {
    let my_hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;

    let me = hunter::Entity::find_by_id(my_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("invalid hunter identity".into()))?;
    let counterpart = hunter::Entity::find_by_id(query.counterpart_hunter_id)
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("counterpart hunter not found".into()))?;
    ensure_friend_link(&state, me.id, counterpart.id).await?;

    let conversation_key = conversation_key(me.id, counterpart.id);
    let limit = query
        .limit
        .unwrap_or(DEFAULT_HISTORY_LIMIT)
        .min(MAX_HISTORY_LIMIT);

    let mut finder = dm_encrypted_message::Entity::find()
        .filter(dm_encrypted_message::Column::ConversationKey.eq(conversation_key))
        .order_by_desc(dm_encrypted_message::Column::SentAt)
        .order_by_desc(dm_encrypted_message::Column::Id);

    if let Some(before_ms) = query.before_ms {
        let before = Utc
            .timestamp_millis_opt(before_ms)
            .single()
            .ok_or_else(|| AppError::BadRequest("invalid before_ms".into()))?;
        finder = finder.filter(dm_encrypted_message::Column::SentAt.lt(before));
    }

    let mut rows = finder.limit(limit).all(&state.db).await?;
    rows.reverse();

    let messages = rows
        .iter()
        .map(|row| {
            let counterpart_model = if row.sender_hunter_id == me.id {
                &counterpart
            } else {
                &me
            };
            map_encrypted_direct_message(row, counterpart_model, DmEncryptionMode::Encrypted)
        })
        .collect();

    Ok(Json(messages))
}

async fn ensure_friend_link(
    state: &AppState,
    source_hunter_id: Uuid,
    target_hunter_id: Uuid,
) -> AppResult<()> {
    let is_friend = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(source_hunter_id))
        .filter(friend_link::Column::FriendId.eq(target_hunter_id))
        .one(&state.db)
        .await?
        .is_some();
    if !is_friend {
        return Err(AppError::Forbidden(
            "direct messages are only available between friends".into(),
        ));
    }
    Ok(())
}

async fn ensure_dm_device_key_access(
    state: &AppState,
    requester_hunter_id: Uuid,
    target_hunter_id: Uuid,
) -> AppResult<()> {
    if requester_hunter_id != target_hunter_id {
        ensure_friend_link(state, requester_hunter_id, target_hunter_id).await?;
    }
    Ok(())
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

async fn upsert_dm_conversation_capability(
    state: &AppState,
    left_hunter_id: Uuid,
    right_hunter_id: Uuid,
    conversation_key: &str,
) -> AppResult<dm_conversation_capability::Model> {
    let (left_hunter_id, right_hunter_id) = sort_hunter_pair(left_hunter_id, right_hunter_id);
    let now = Utc::now();
    let existing = dm_conversation_capability::Entity::find_by_id(conversation_key.to_string())
        .one(&state.db)
        .await?;

    let model = if let Some(existing) = existing {
        let needs_upgrade_timestamp = existing.upgraded_at.is_none();
        let mut active = existing.into_active_model();
        active.encryption_mode = Set(DmEncryptionMode::Encrypted);
        if needs_upgrade_timestamp {
            active.upgraded_at = Set(Some(now.into()));
        }
        active.last_handshake_at = Set(Some(now.into()));
        active.update(&state.db).await?
    } else {
        dm_conversation_capability::ActiveModel {
            conversation_key: Set(conversation_key.to_string()),
            left_hunter_id: Set(left_hunter_id),
            right_hunter_id: Set(right_hunter_id),
            encryption_mode: Set(DmEncryptionMode::Encrypted),
            upgraded_at: Set(Some(now.into())),
            last_handshake_at: Set(Some(now.into())),
        }
        .insert(&state.db)
        .await?
    };

    Ok(model)
}

fn conversation_key(a: Uuid, b: Uuid) -> String {
    let left = a.to_string();
    let right = b.to_string();
    if left <= right {
        format!("{left}:{right}")
    } else {
        format!("{right}:{left}")
    }
}

fn sort_hunter_pair(a: Uuid, b: Uuid) -> (Uuid, Uuid) {
    if a.to_string() <= b.to_string() {
        (a, b)
    } else {
        (b, a)
    }
}

async fn load_latest_thread_candidates(
    state: &AppState,
    my_hunter_id: Uuid,
    limit: u64,
) -> AppResult<Vec<ThreadPreviewCandidate>> {
    let backend = state.db.get_database_backend();
    let rows = state
        .db
        .query_all(Statement::from_sql_and_values(
            backend,
            r#"
WITH unioned AS (
    SELECT
        conversation_key,
        sender_hunter_id,
        recipient_hunter_id,
        content AS last_message,
        sent_at AS last_message_at,
        'plaintext'::text AS encryption_mode,
        id::text AS tie_breaker
    FROM direct_messages
    WHERE sender_hunter_id = $1 OR recipient_hunter_id = $1
    UNION ALL
    SELECT
        conversation_key,
        sender_hunter_id,
        recipient_hunter_id,
        'Encrypted message'::text AS last_message,
        sent_at AS last_message_at,
        'encrypted'::text AS encryption_mode,
        id::text AS tie_breaker
    FROM dm_encrypted_messages
    WHERE sender_hunter_id = $1 OR recipient_hunter_id = $1
),
ranked AS (
    SELECT
        conversation_key,
        sender_hunter_id,
        recipient_hunter_id,
        last_message,
        last_message_at,
        encryption_mode,
        ROW_NUMBER() OVER (
            PARTITION BY conversation_key
            ORDER BY last_message_at DESC, tie_breaker DESC
        ) AS row_rank
    FROM unioned
)
SELECT
    conversation_key,
    sender_hunter_id,
    recipient_hunter_id,
    last_message,
    last_message_at,
    encryption_mode
FROM ranked
WHERE row_rank = 1
ORDER BY last_message_at DESC
LIMIT $2
            "#,
            vec![Value::from(my_hunter_id), Value::from(limit as i64)],
        ))
        .await?;

    let mut out = Vec::with_capacity(rows.len());
    for row in rows {
        let mode_raw: String = row.try_get("", "encryption_mode")?;
        let encryption_mode = match mode_raw.as_str() {
            "encrypted" => DmEncryptionMode::Encrypted,
            _ => DmEncryptionMode::Plaintext,
        };
        out.push(ThreadPreviewCandidate {
            conversation_key: row.try_get("", "conversation_key")?,
            sender_hunter_id: row.try_get("", "sender_hunter_id")?,
            recipient_hunter_id: row.try_get("", "recipient_hunter_id")?,
            last_message: row.try_get("", "last_message")?,
            last_message_at: row.try_get("", "last_message_at")?,
            encryption_mode,
        });
    }
    Ok(out)
}

async fn load_latest_thread_candidates_fallback(
    state: &AppState,
    my_hunter_id: Uuid,
    limit: u64,
) -> AppResult<Vec<ThreadPreviewCandidate>> {
    let plain_rows = direct_message::Entity::find()
        .filter(
            Condition::any()
                .add(direct_message::Column::SenderHunterId.eq(my_hunter_id))
                .add(direct_message::Column::RecipientHunterId.eq(my_hunter_id)),
        )
        .order_by_desc(direct_message::Column::SentAt)
        .order_by_desc(direct_message::Column::Id)
        .all(&state.db)
        .await?;
    let encrypted_rows = dm_encrypted_message::Entity::find()
        .filter(
            Condition::any()
                .add(dm_encrypted_message::Column::SenderHunterId.eq(my_hunter_id))
                .add(dm_encrypted_message::Column::RecipientHunterId.eq(my_hunter_id)),
        )
        .order_by_desc(dm_encrypted_message::Column::SentAt)
        .order_by_desc(dm_encrypted_message::Column::Id)
        .all(&state.db)
        .await?;

    let mut latest_by_conversation: HashMap<String, ThreadPreviewCandidate> = HashMap::new();
    for row in plain_rows {
        let candidate = ThreadPreviewCandidate::from_plain(row);
        upsert_thread_preview(&mut latest_by_conversation, candidate);
    }
    for row in encrypted_rows {
        let candidate = ThreadPreviewCandidate::from_encrypted(row);
        upsert_thread_preview(&mut latest_by_conversation, candidate);
    }

    let mut latest_rows = latest_by_conversation.into_values().collect::<Vec<_>>();
    latest_rows.sort_by(|a, b| b.last_message_at.cmp(&a.last_message_at));
    latest_rows.truncate(limit as usize);
    Ok(latest_rows)
}

async fn load_unread_counts_for_threads(
    state: &AppState,
    my_hunter_id: Uuid,
    conversation_keys: &[String],
) -> AppResult<HashMap<String, u64>> {
    if conversation_keys.is_empty() {
        return Ok(HashMap::new());
    }

    let backend = state.db.get_database_backend();
    let (sql, values) = if backend == sea_orm::DatabaseBackend::Postgres {
        let placeholders = (2..(2 + conversation_keys.len()))
            .map(|idx| format!("${idx}"))
            .collect::<Vec<_>>()
            .join(", ");
        let sql = format!(
            r#"
SELECT unread.conversation_key, COUNT(*)::BIGINT AS unread_count
FROM (
    SELECT dm.conversation_key
    FROM direct_messages dm
    LEFT JOIN dm_thread_reads dr
        ON dr.hunter_id = $1
       AND dr.conversation_key = dm.conversation_key
    WHERE dm.sender_hunter_id <> $1
      AND dm.conversation_key IN ({placeholders})
      AND (dr.last_read_at IS NULL OR dm.sent_at > dr.last_read_at)
    UNION ALL
    SELECT em.conversation_key
    FROM dm_encrypted_messages em
    LEFT JOIN dm_thread_reads dr
        ON dr.hunter_id = $1
       AND dr.conversation_key = em.conversation_key
    WHERE em.sender_hunter_id <> $1
      AND em.conversation_key IN ({placeholders})
      AND (dr.last_read_at IS NULL OR em.sent_at > dr.last_read_at)
) unread
GROUP BY unread.conversation_key
            "#
        );
        let mut values = Vec::with_capacity(1 + conversation_keys.len());
        values.push(Value::from(my_hunter_id));
        values.extend(conversation_keys.iter().cloned().map(Value::from));
        (sql, values)
    } else {
        let placeholders = std::iter::repeat_n("?", conversation_keys.len())
            .collect::<Vec<_>>()
            .join(", ");
        let sql = format!(
            r#"
SELECT unread.conversation_key, COUNT(*) AS unread_count
FROM (
    SELECT dm.conversation_key
    FROM direct_messages dm
    LEFT JOIN dm_thread_reads dr
        ON dr.hunter_id = ?
       AND dr.conversation_key = dm.conversation_key
    WHERE dm.sender_hunter_id <> ?
      AND dm.conversation_key IN ({placeholders})
      AND (dr.last_read_at IS NULL OR dm.sent_at > dr.last_read_at)
    UNION ALL
    SELECT em.conversation_key
    FROM dm_encrypted_messages em
    LEFT JOIN dm_thread_reads dr
        ON dr.hunter_id = ?
       AND dr.conversation_key = em.conversation_key
    WHERE em.sender_hunter_id <> ?
      AND em.conversation_key IN ({placeholders})
      AND (dr.last_read_at IS NULL OR em.sent_at > dr.last_read_at)
) unread
GROUP BY unread.conversation_key
            "#
        );
        let mut values = Vec::with_capacity(4 + (conversation_keys.len() * 2));
        values.push(Value::from(my_hunter_id));
        values.push(Value::from(my_hunter_id));
        values.extend(conversation_keys.iter().cloned().map(Value::from));
        values.push(Value::from(my_hunter_id));
        values.push(Value::from(my_hunter_id));
        values.extend(conversation_keys.iter().cloned().map(Value::from));
        (sql, values)
    };

    let rows = state
        .db
        .query_all(Statement::from_sql_and_values(backend, sql, values))
        .await?;

    let mut unread_by_conversation = HashMap::new();
    for row in rows {
        let conversation_key: String = row.try_get("", "conversation_key")?;
        let unread_count: i64 = row.try_get("", "unread_count")?;
        unread_by_conversation.insert(conversation_key, unread_count.max(0) as u64);
    }
    Ok(unread_by_conversation)
}

#[derive(Debug, Clone)]
struct ThreadPreviewCandidate {
    conversation_key: String,
    sender_hunter_id: Uuid,
    recipient_hunter_id: Uuid,
    last_message: String,
    last_message_at: chrono::DateTime<chrono::Utc>,
    encryption_mode: DmEncryptionMode,
}

impl ThreadPreviewCandidate {
    fn from_plain(model: direct_message::Model) -> Self {
        Self {
            conversation_key: model.conversation_key,
            sender_hunter_id: model.sender_hunter_id,
            recipient_hunter_id: model.recipient_hunter_id,
            last_message: model.content,
            last_message_at: model.sent_at.with_timezone(&Utc),
            encryption_mode: DmEncryptionMode::Plaintext,
        }
    }

    fn from_encrypted(model: dm_encrypted_message::Model) -> Self {
        Self {
            conversation_key: model.conversation_key,
            sender_hunter_id: model.sender_hunter_id,
            recipient_hunter_id: model.recipient_hunter_id,
            last_message: "Encrypted message".to_string(),
            last_message_at: model.sent_at.with_timezone(&Utc),
            encryption_mode: DmEncryptionMode::Encrypted,
        }
    }
}

fn upsert_thread_preview(
    latest_by_conversation: &mut HashMap<String, ThreadPreviewCandidate>,
    candidate: ThreadPreviewCandidate,
) {
    match latest_by_conversation.get(&candidate.conversation_key) {
        Some(existing) if existing.last_message_at >= candidate.last_message_at => {}
        _ => {
            latest_by_conversation.insert(candidate.conversation_key.clone(), candidate);
        }
    }
}

fn normalize_device_id(raw: &str) -> AppResult<String> {
    let value = raw.trim();
    if value.is_empty() {
        return Err(AppError::BadRequest("device_id must not be empty".into()));
    }
    if value.chars().count() > MAX_DM_DEVICE_ID_LEN {
        return Err(AppError::BadRequest(format!(
            "device_id too long, max {} characters",
            MAX_DM_DEVICE_ID_LEN
        )));
    }
    Ok(value.to_string())
}

fn parse_batch_hunter_ids(raw: Option<String>) -> AppResult<Vec<Uuid>> {
    let Some(raw) = raw else {
        return Ok(Vec::new());
    };
    let mut ids = Vec::new();
    let mut seen = HashSet::new();
    for token in raw
        .split(',')
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        let hunter_id = Uuid::parse_str(token)
            .map_err(|_| AppError::BadRequest("hunter_ids contains invalid uuid".into()))?;
        if seen.insert(hunter_id) {
            ids.push(hunter_id);
        }
        if ids.len() > 80 {
            return Err(AppError::BadRequest(
                "hunter_ids exceeds maximum batch size of 80".into(),
            ));
        }
    }
    Ok(ids)
}

fn normalize_optional_trimmed(value: Option<String>, max_len: usize) -> AppResult<Option<String>> {
    match value {
        Some(value) => {
            let trimmed = value.trim();
            if trimmed.is_empty() {
                Ok(None)
            } else if trimmed.chars().count() > max_len {
                Err(AppError::BadRequest(format!(
                    "value too long, max {} characters",
                    max_len
                )))
            } else {
                Ok(Some(trimmed.to_string()))
            }
        }
        None => Ok(None),
    }
}

fn normalize_required_text(field: &str, raw: &str, max_len: usize) -> AppResult<String> {
    let value = raw.trim();
    if value.is_empty() {
        return Err(AppError::BadRequest(format!("{field} must not be empty")));
    }
    if value.chars().count() > max_len {
        return Err(AppError::BadRequest(format!(
            "{field} too long, max {} characters",
            max_len
        )));
    }
    Ok(value.to_string())
}

fn normalize_protocol_version(value: Option<String>) -> AppResult<String> {
    match value {
        Some(value) => {
            normalize_required_text("protocol_version", &value, MAX_DM_PROTOCOL_VERSION_LEN)
        }
        None => Ok("dm-e2ee-v1".to_string()),
    }
}

fn map_direct_message(
    model: &direct_message::Model,
    sender: &hunter::Model,
    counterpart: &hunter::Model,
) -> DirectMessageResponse {
    let sent_at = model.sent_at.with_timezone(&Utc);
    DirectMessageResponse {
        id: model.id,
        sender_hunter_id: model.sender_hunter_id,
        recipient_hunter_id: model.recipient_hunter_id,
        counterpart_hunter_id: counterpart.id,
        counterpart_name: counterpart.name.clone(),
        counterpart_player_id: counterpart.player_id.clone(),
        counterpart_guild_id: counterpart.guild_id,
        sender_name: sender.name.clone(),
        client_message_id: model.client_message_id,
        content: model.content.clone(),
        sent_at,
        sent_at_ms: sent_at.timestamp_millis(),
    }
}

fn map_thread_candidate(
    model: &ThreadPreviewCandidate,
    counterpart: &hunter::Model,
    sender: &hunter::Model,
    encryption_mode: DmEncryptionMode,
    unread_count: u64,
) -> DirectMessageThreadResponse {
    DirectMessageThreadResponse {
        conversation_key: model.conversation_key.clone(),
        counterpart_hunter_id: counterpart.id,
        counterpart_name: counterpart.name.clone(),
        counterpart_player_id: counterpart.player_id.clone(),
        counterpart_guild_id: counterpart.guild_id,
        counterpart_avatar_type: counterpart.avatar_type.clone(),
        last_message: model.last_message.clone(),
        last_message_sender_hunter_id: model.sender_hunter_id,
        last_message_sender_name: sender.name.clone(),
        last_message_at: model.last_message_at,
        last_message_at_ms: model.last_message_at.timestamp_millis(),
        encryption_mode,
        unread_count,
    }
}

fn map_dm_device_key(model: &dm_device_key::Model) -> DmDeviceKeyResponse {
    DmDeviceKeyResponse {
        id: model.id,
        hunter_id: model.hunter_id,
        device_id: model.device_id.clone(),
        device_label: model.device_label.clone(),
        signing_public_key: model.signing_public_key.clone(),
        encryption_public_key: model.encryption_public_key.clone(),
        created_at: model.created_at.with_timezone(&Utc),
        last_seen_at: model.last_seen_at.with_timezone(&Utc),
        revoked_at: model.revoked_at.map(|value| value.with_timezone(&Utc)),
    }
}

fn map_encrypted_direct_message(
    model: &dm_encrypted_message::Model,
    counterpart: &hunter::Model,
    encryption_mode: DmEncryptionMode,
) -> EncryptedDirectMessageResponse {
    let sent_at = model.sent_at.with_timezone(&Utc);
    EncryptedDirectMessageResponse {
        id: model.id,
        sender_hunter_id: model.sender_hunter_id,
        recipient_hunter_id: model.recipient_hunter_id,
        counterpart_hunter_id: counterpart.id,
        counterpart_name: counterpart.name.clone(),
        counterpart_player_id: counterpart.player_id.clone(),
        counterpart_guild_id: counterpart.guild_id,
        sender_device_id: model.sender_device_id.clone(),
        recipient_device_id: model.recipient_device_id.clone(),
        client_message_id: model.client_message_id,
        protocol_version: model.protocol_version.clone(),
        ciphertext: model.ciphertext.clone(),
        nonce: model.nonce.clone(),
        sent_at,
        sent_at_ms: sent_at.timestamp_millis(),
        encryption_mode,
    }
}

async fn latest_message_timestamp_for_conversation(
    state: &AppState,
    conversation_key: &str,
) -> AppResult<Option<chrono::DateTime<chrono::Utc>>> {
    let plain_latest = direct_message::Entity::find()
        .filter(direct_message::Column::ConversationKey.eq(conversation_key.to_string()))
        .order_by_desc(direct_message::Column::SentAt)
        .one(&state.db)
        .await?
        .map(|row| row.sent_at.with_timezone(&Utc));
    let encrypted_latest = dm_encrypted_message::Entity::find()
        .filter(dm_encrypted_message::Column::ConversationKey.eq(conversation_key.to_string()))
        .order_by_desc(dm_encrypted_message::Column::SentAt)
        .one(&state.db)
        .await?
        .map(|row| row.sent_at.with_timezone(&Utc));

    Ok(match (plain_latest, encrypted_latest) {
        (Some(left), Some(right)) => Some(if left >= right { left } else { right }),
        (Some(left), None) => Some(left),
        (None, Some(right)) => Some(right),
        (None, None) => None,
    })
}

fn is_dm_dedupe_violation(err: &DbErr) -> bool {
    match err.sql_err() {
        Some(sea_orm::SqlErr::UniqueConstraintViolation(message)) => {
            message.contains("idx_direct_messages_conversation_client_unique")
                || message.contains("direct_messages_conversation_key_client_message_id")
                || message.contains("client_message_id")
        }
        _ => false,
    }
}

fn is_encrypted_dm_dedupe_violation(err: &DbErr) -> bool {
    match err.sql_err() {
        Some(sea_orm::SqlErr::UniqueConstraintViolation(message)) => {
            message.contains("idx_dm_encrypted_conversation_client_unique")
                || message.contains("dm_encrypted_messages_conversation_key_client_message_id")
                || message.contains("client_message_id")
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;

    use axum::{
        Json,
        extract::{Path, Query, State},
    };
    use chrono::Utc;
    use entity::{dm_conversation_capability::DmEncryptionMode, friend_link, guild, hunter, user};
    use migration::MigratorTrait;
    use sea_orm::{
        ActiveModelTrait, ActiveValue::Set, ConnectionTrait, Database, DatabaseBackend,
        EntityTrait, Statement,
    };
    use uuid::Uuid;

    use crate::{
        extractors::HunterClaims,
        jwt::{AuthRole, Claims, GuildRole, JwtService},
        state::AppState,
    };

    use super::{
        BatchDmDeviceKeysQuery, DirectMessageHistoryQuery, DirectMessageThreadsQuery,
        EncryptedDirectMessageHistoryQuery, PersistDirectMessageRequest,
        PersistEncryptedDirectMessageRequest, RegisterDmDeviceKeyRequest, RevokeDmDeviceKeyRequest,
        list_direct_message_history, list_direct_message_threads, list_dm_device_keys,
        list_dm_device_keys_batch, list_encrypted_direct_message_history,
        mark_direct_message_thread_read, persist_direct_message, persist_encrypted_direct_message,
        register_dm_device_key, revoke_dm_device_key,
    };

    #[tokio::test]
    async fn persist_and_list_direct_message_history() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, bob_id) = ctx.seed_friend_pair("dm").await?;

        let (_, saved) = persist_direct_message(
            alice_claims.clone(),
            State(state.clone()),
            Json(PersistDirectMessageRequest {
                recipient_hunter_id: bob_id,
                client_message_id: Some(Uuid::new_v4()),
                content: "See you after dinner".to_string(),
                sent_at_ms: None,
            }),
        )
        .await?;

        assert_eq!(saved.counterpart_hunter_id, bob_id);
        assert_eq!(saved.content, "See you after dinner");

        let history = list_direct_message_history(
            alice_claims,
            State(state),
            Query(DirectMessageHistoryQuery {
                counterpart_hunter_id: bob_id,
                limit: Some(20),
                before_ms: None,
            }),
        )
        .await?;
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].content, "See you after dinner");

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn list_threads_returns_latest_message_per_friend() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, bob_id) = ctx.seed_friend_pair("threads").await?;

        let second_friend = ctx.seed_extra_friend(&state, "charlie").await?;
        ctx.link_friends(&state, alice_claims.0.sub, second_friend)
            .await?;

        let _ = persist_direct_message(
            alice_claims.clone(),
            State(state.clone()),
            Json(PersistDirectMessageRequest {
                recipient_hunter_id: bob_id,
                client_message_id: Some(Uuid::new_v4()),
                content: "First thread".to_string(),
                sent_at_ms: Some(Utc::now().timestamp_millis() - 2000),
            }),
        )
        .await?;

        let _ = persist_direct_message(
            alice_claims.clone(),
            State(state.clone()),
            Json(PersistDirectMessageRequest {
                recipient_hunter_id: second_friend,
                client_message_id: Some(Uuid::new_v4()),
                content: "Second thread".to_string(),
                sent_at_ms: Some(Utc::now().timestamp_millis() - 1000),
            }),
        )
        .await?;

        let threads = list_direct_message_threads(
            alice_claims,
            State(state),
            Query(DirectMessageThreadsQuery { limit: Some(10) }),
        )
        .await?;

        assert_eq!(threads.len(), 2);
        assert_eq!(threads[0].last_message, "Second thread");
        assert_eq!(threads[1].last_message, "First thread");

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn direct_messages_require_friendship() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, _bob_id) = ctx.seed_friend_pair("guard").await?;
        let stranger_id = ctx.seed_extra_friend(&state, "stranger").await?;

        let err = persist_direct_message(
            alice_claims,
            State(state),
            Json(PersistDirectMessageRequest {
                recipient_hunter_id: stranger_id,
                client_message_id: Some(Uuid::new_v4()),
                content: "Hello".to_string(),
                sent_at_ms: None,
            }),
        )
        .await
        .expect_err("strangers should not DM");

        assert!(matches!(err, crate::error::AppError::Forbidden(_)));
        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn mark_thread_read_clears_unread_count() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, bob_id) = ctx.seed_friend_pair("read_cursor").await?;
        let bob_claims = ctx.claims_for(&state, bob_id).await?;

        let _ = persist_direct_message(
            bob_claims.clone(),
            State(state.clone()),
            Json(PersistDirectMessageRequest {
                recipient_hunter_id: alice_claims.0.sub,
                client_message_id: Some(Uuid::new_v4()),
                content: "first unread".to_string(),
                sent_at_ms: Some(Utc::now().timestamp_millis() - 2000),
            }),
        )
        .await?;
        let _ = persist_direct_message(
            bob_claims,
            State(state.clone()),
            Json(PersistDirectMessageRequest {
                recipient_hunter_id: alice_claims.0.sub,
                client_message_id: Some(Uuid::new_v4()),
                content: "second unread".to_string(),
                sent_at_ms: Some(Utc::now().timestamp_millis() - 1000),
            }),
        )
        .await?;

        let before = list_direct_message_threads(
            alice_claims.clone(),
            State(state.clone()),
            Query(DirectMessageThreadsQuery { limit: Some(10) }),
        )
        .await?;
        assert_eq!(before.len(), 1);
        assert_eq!(before[0].unread_count, 2);

        let read_state = mark_direct_message_thread_read(
            alice_claims.clone(),
            State(state.clone()),
            Path(bob_id),
        )
        .await?;
        assert_eq!(read_state.unread_count, 0);

        let after = list_direct_message_threads(
            alice_claims,
            State(state),
            Query(DirectMessageThreadsQuery { limit: Some(10) }),
        )
        .await?;
        assert_eq!(after.len(), 1);
        assert_eq!(after[0].unread_count, 0);

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn register_list_and_revoke_dm_device_keys() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, bob_id) = ctx.seed_friend_pair("device_keys").await?;
        let bob_claims = ctx.claims_for(&state, bob_id).await?;

        let (_, alice_key) = register_dm_device_key(
            alice_claims.clone(),
            State(state.clone()),
            Json(RegisterDmDeviceKeyRequest {
                device_id: "alice-ios".to_string(),
                device_label: Some("Alice iPhone".to_string()),
                signing_public_key: "alice-signing-key".to_string(),
                encryption_public_key: "alice-encryption-key".to_string(),
            }),
        )
        .await?;
        assert_eq!(alice_key.device_id, "alice-ios");

        let (_, bob_key) = register_dm_device_key(
            bob_claims,
            State(state.clone()),
            Json(RegisterDmDeviceKeyRequest {
                device_id: "bob-ios".to_string(),
                device_label: Some("Bob iPhone".to_string()),
                signing_public_key: "bob-signing-key".to_string(),
                encryption_public_key: "bob-encryption-key".to_string(),
            }),
        )
        .await?;
        assert_eq!(bob_key.device_id, "bob-ios");

        let alice_keys = list_dm_device_keys(
            alice_claims.clone(),
            State(state.clone()),
            Path(alice_claims.0.sub),
        )
        .await?;
        assert_eq!(alice_keys.len(), 1);
        assert_eq!(alice_keys[0].device_id, "alice-ios");

        let friend_keys =
            list_dm_device_keys(alice_claims.clone(), State(state.clone()), Path(bob_id)).await?;
        assert_eq!(friend_keys.len(), 1);
        assert_eq!(friend_keys[0].device_id, "bob-ios");

        let revoked = revoke_dm_device_key(
            alice_claims.clone(),
            State(state.clone()),
            Json(RevokeDmDeviceKeyRequest {
                device_id: "alice-ios".to_string(),
            }),
        )
        .await?;
        assert!(revoked.revoked_at.is_some());

        let alice_keys_after_revoke =
            list_dm_device_keys(alice_claims, State(state.clone()), Path(revoked.hunter_id))
                .await?;
        assert!(alice_keys_after_revoke.is_empty());

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn list_dm_device_keys_batch_returns_requested_order() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, bob_id) = ctx.seed_friend_pair("batch_keys").await?;
        let bob_claims = ctx.claims_for(&state, bob_id).await?;

        let _ = register_dm_device_key(
            alice_claims.clone(),
            State(state.clone()),
            Json(RegisterDmDeviceKeyRequest {
                device_id: "alice-main".to_string(),
                device_label: Some("Alice Main".to_string()),
                signing_public_key: "alice-signing-key".to_string(),
                encryption_public_key: "alice-encryption-key".to_string(),
            }),
        )
        .await?;
        let _ = register_dm_device_key(
            bob_claims,
            State(state.clone()),
            Json(RegisterDmDeviceKeyRequest {
                device_id: "bob-main".to_string(),
                device_label: Some("Bob Main".to_string()),
                signing_public_key: "bob-signing-key".to_string(),
                encryption_public_key: "bob-encryption-key".to_string(),
            }),
        )
        .await?;

        let requested = format!("{},{}", bob_id, alice_claims.0.sub);
        let response = list_dm_device_keys_batch(
            alice_claims,
            State(state),
            Query(BatchDmDeviceKeysQuery {
                hunter_ids: Some(requested),
            }),
        )
        .await?;

        assert_eq!(response.len(), 2);
        assert_eq!(response[0].hunter_id, bob_id);
        assert_eq!(response[0].keys.len(), 1);
        assert_eq!(response[0].keys[0].device_id, "bob-main");
        assert_eq!(response[1].keys.len(), 1);
        assert_eq!(response[1].keys[0].device_id, "alice-main");

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn persist_and_list_encrypted_direct_message_history() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, alice_claims, bob_id) = ctx.seed_friend_pair("enc_dm").await?;
        let bob_claims = ctx.claims_for(&state, bob_id).await?;

        let _ = register_dm_device_key(
            alice_claims.clone(),
            State(state.clone()),
            Json(RegisterDmDeviceKeyRequest {
                device_id: "alice-main".to_string(),
                device_label: Some("Alice Main".to_string()),
                signing_public_key: "alice-signing-public".to_string(),
                encryption_public_key: "alice-encryption-public".to_string(),
            }),
        )
        .await?;
        let _ = register_dm_device_key(
            bob_claims,
            State(state.clone()),
            Json(RegisterDmDeviceKeyRequest {
                device_id: "bob-main".to_string(),
                device_label: Some("Bob Main".to_string()),
                signing_public_key: "bob-signing-public".to_string(),
                encryption_public_key: "bob-encryption-public".to_string(),
            }),
        )
        .await?;

        let (_, saved) = persist_encrypted_direct_message(
            alice_claims.clone(),
            State(state.clone()),
            Json(PersistEncryptedDirectMessageRequest {
                recipient_hunter_id: bob_id,
                sender_device_id: "alice-main".to_string(),
                recipient_device_id: "bob-main".to_string(),
                client_message_id: Some(Uuid::new_v4()),
                protocol_version: Some("dm-e2ee-v1".to_string()),
                ciphertext: "ciphertext:demo".to_string(),
                nonce: "nonce-demo".to_string(),
                sent_at_ms: Some(Utc::now().timestamp_millis()),
            }),
        )
        .await?;
        assert_eq!(saved.ciphertext, "ciphertext:demo");
        assert_eq!(saved.encryption_mode, DmEncryptionMode::Encrypted);

        let history = list_encrypted_direct_message_history(
            alice_claims.clone(),
            State(state.clone()),
            Query(EncryptedDirectMessageHistoryQuery {
                counterpart_hunter_id: bob_id,
                limit: Some(20),
                before_ms: None,
            }),
        )
        .await?;
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].nonce, "nonce-demo");
        assert_eq!(history[0].encryption_mode, DmEncryptionMode::Encrypted);

        let threads = list_direct_message_threads(
            alice_claims,
            State(state),
            Query(DirectMessageThreadsQuery { limit: Some(10) }),
        )
        .await?;
        assert_eq!(threads.len(), 1);
        assert_eq!(threads[0].last_message, "Encrypted message");
        assert_eq!(threads[0].encryption_mode, DmEncryptionMode::Encrypted);

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
                "postgres://chen:chen@127.0.0.1:5433/the_bit_and_bond".to_string()
            });
            let db_name = format!("the_bit_and_bond_it_dm_{}", Uuid::new_v4().simple());
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

        async fn seed_friend_pair(
            &self,
            suffix: &str,
        ) -> Result<(AppState, HunterClaims, Uuid), Box<dyn Error>> {
            let guild_a = self
                .seed_guild_with_hunter(&format!("{suffix}_a"), true)
                .await?;
            let guild_b = self
                .seed_guild_with_hunter(&format!("{suffix}_b"), false)
                .await?;
            self.link_friends(&guild_a.state, guild_a.hunter_id, guild_b.hunter_id)
                .await?;
            self.link_friends(&guild_a.state, guild_b.hunter_id, guild_a.hunter_id)
                .await?;
            Ok((guild_a.state, guild_a.claims, guild_b.hunter_id))
        }

        async fn seed_extra_friend(
            &self,
            state: &AppState,
            suffix: &str,
        ) -> Result<Uuid, Box<dyn Error>> {
            let guild = self.seed_guild_with_hunter(suffix, false).await?;
            let _ = state;
            Ok(guild.hunter_id)
        }

        async fn claims_for(
            &self,
            state: &AppState,
            hunter_id: Uuid,
        ) -> Result<HunterClaims, Box<dyn Error>> {
            let hunter = hunter::Entity::find_by_id(hunter_id)
                .one(&state.db)
                .await?
                .ok_or("hunter not found")?;
            Ok(HunterClaims(Claims {
                sub: hunter.id,
                role: AuthRole::Player,
                guild_role: GuildRole::Member,
                guild_id: hunter.guild_id,
                hunter_id: Some(hunter.id),
                iat: 0,
                exp: 9_999_999_999,
            }))
        }

        async fn link_friends(
            &self,
            state: &AppState,
            source: Uuid,
            target: Uuid,
        ) -> Result<(), Box<dyn Error>> {
            friend_link::ActiveModel {
                id: Set(Uuid::new_v4()),
                player_id: Set(source),
                friend_id: Set(target),
                created_at: Set(Utc::now()),
            }
            .insert(&state.db)
            .await?;
            Ok(())
        }

        async fn seed_guild_with_hunter(
            &self,
            suffix: &str,
            return_claims: bool,
        ) -> Result<SeededGuild, Box<dyn Error>> {
            let user_id = Uuid::new_v4();
            let guild_id = Uuid::new_v4();
            let hunter_id = Uuid::new_v4();

            user::ActiveModel {
                id: Set(user_id),
                email: Set(format!("{suffix}@example.com")),
                password_hash: Set("$argon2id$fake$hash".to_string()),
                hunter_tag: Set(format!("TAG{}", suffix.to_ascii_uppercase())),
                current_role: Set("Guardian".to_string()),
                created_at: Set(Utc::now()),
            }
            .insert(&self.app_db)
            .await?;

            guild::ActiveModel {
                id: Set(guild_id),
                name: Set(format!("guild-{suffix}")),
                owner_id: Set(user_id),
                invite_code: Set(Uuid::new_v4()
                    .simple()
                    .to_string()
                    .chars()
                    .take(6)
                    .collect()),
            }
            .insert(&self.app_db)
            .await?;

            hunter::ActiveModel {
                id: Set(hunter_id),
                guild_id: Set(guild_id),
                user_id: Set(Some(user_id)),
                player_id: Set(format!("player_{suffix}")),
                name: Set(format!("Player {suffix}")),
                avatar_type: Set("default".to_string()),
                level: Set(1),
                xp: Set(0),
                coins: Set(0),
                pin_code: Set("$argon2id$seed".to_string()),
                guild_role: Set("member".to_string()),
                motto: Set(None),
            }
            .insert(&self.app_db)
            .await?;

            let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
            let state = AppState::new(self.app_db.clone(), jwt);
            let claims = HunterClaims(Claims {
                sub: hunter_id,
                role: AuthRole::Player,
                guild_role: GuildRole::Member,
                guild_id,
                hunter_id: Some(hunter_id),
                iat: 0,
                exp: 9_999_999_999,
            });

            let _ = return_claims;
            Ok(SeededGuild {
                state,
                claims,
                hunter_id,
            })
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

    struct SeededGuild {
        state: AppState,
        claims: HunterClaims,
        hunter_id: Uuid,
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
