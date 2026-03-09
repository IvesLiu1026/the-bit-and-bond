use axum::{
    Json,
    body::Body,
    extract::{Multipart, Path, State},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    response::IntoResponse,
};
use chrono::{Datelike, Days, NaiveDate, Utc};
use entity::{
    hunter,
    hunter_reward_ledger::{self, LedgerEventType},
    quest::{self, HabitCadence, QuestCategory, QuestStatCategory, QuestStatus},
    quest_proof_media,
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, DatabaseTransaction,
    EntityTrait, QueryFilter, QueryOrder, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, path::PathBuf};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, GuildMasterClaims, HunterClaims, require_guild_owner},
    jwt::GuildRole,
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct CreateQuestRequest {
    pub title: String,
    pub description: Option<String>,
    pub reward_xp: i32,
    pub reward_coins: i32,
    #[serde(default = "default_quest_stat_category")]
    pub stat_category: QuestStatCategory,
    #[serde(default = "default_quest_category")]
    pub category: QuestCategory,
    pub assigned_hunter_id: Option<Uuid>,
    pub cadence: Option<HabitCadence>,
}

#[derive(Debug, Deserialize)]
pub struct SubmitQuestRequest {
    pub proof_note: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ReviewQuestRequest {
    pub approved: bool,
    pub hunter_id: Option<Uuid>,
    pub review_note: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct QuestResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub reward_xp: i32,
    pub reward_coins: i32,
    pub stat_category: QuestStatCategory,
    pub category: QuestCategory,
    pub assigned_hunter_id: Option<Uuid>,
    pub created_by_hunter_id: Option<Uuid>,
    pub cadence: Option<HabitCadence>,
    pub streak_count: i32,
    pub best_streak: i32,
    pub completions_count: i32,
    pub proof_note: Option<String>,
    pub proof_submitted_at: Option<chrono::DateTime<chrono::FixedOffset>>,
    pub last_completed_at: Option<NaiveDate>,
    pub last_review_note: Option<String>,
    pub proof_media: Vec<QuestProofMediaResponse>,
    pub updated_at: chrono::DateTime<chrono::FixedOffset>,
    pub status: QuestStatus,
}

#[derive(Debug, Clone, Serialize)]
pub struct QuestProofMediaResponse {
    pub id: Uuid,
    pub quest_id: Uuid,
    pub original_filename: Option<String>,
    pub mime_type: String,
    pub byte_size: i64,
    pub content_path: String,
    pub created_at: chrono::DateTime<chrono::FixedOffset>,
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
    pub reward: Option<ReviewRewardEvent>,
}

#[derive(Debug, Serialize)]
pub struct ReviewRewardEvent {
    pub reward_event_id: Uuid,
    pub hunter_id: Uuid,
    pub gained_xp: i32,
    pub gained_coins: i32,
    pub leveled_up: bool,
    pub new_level: i32,
}

pub async fn create_quest(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Json(payload): Json<CreateQuestRequest>,
) -> AppResult<(StatusCode, Json<QuestResponse>)> {
    require_guild_owner(&claims)?;
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

    let description = normalize_optional_text(payload.description);
    let cadence = normalize_cadence(payload.category.clone(), payload.cadence)?;
    if let Some(assigned_hunter_id) = payload.assigned_hunter_id {
        let assigned_exists = hunter::Entity::find_by_id(assigned_hunter_id)
            .filter(hunter::Column::GuildId.eq(claims.guild_id))
            .one(&state.db)
            .await?
            .is_some();
        if !assigned_exists {
            return Err(AppError::BadRequest(
                "assigned_hunter_id does not exist in current guild".into(),
            ));
        }
    }
    let now = Utc::now();

    let created = quest::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(claims.guild_id),
        title: Set(title.to_string()),
        description: Set(description),
        reward_xp: Set(payload.reward_xp),
        reward_coins: Set(payload.reward_coins),
        stat_category: Set(payload.stat_category),
        category: Set(payload.category),
        assigned_hunter_id: Set(payload.assigned_hunter_id),
        created_by_hunter_id: Set(claims.hunter_id),
        cadence: Set(cadence),
        streak_count: Set(0),
        best_streak: Set(0),
        completions_count: Set(0),
        proof_note: Set(None),
        proof_submitted_at: Set(None),
        last_completed_at: Set(None),
        last_review_note: Set(None),
        updated_at: Set(now.into()),
        status: Set(QuestStatus::Available),
    }
    .insert(&state.db)
    .await?;

    Ok((StatusCode::CREATED, Json(map_quest(created, Vec::new()))))
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

    let media_map = load_quest_proof_media_map(
        &state.db,
        &rows.iter().map(|row| row.id).collect::<Vec<_>>(),
    )
    .await?;

    Ok(Json(
        rows.into_iter()
            .map(|row| {
                let proof_media = media_map.get(&row.id).cloned().unwrap_or_default();
                map_quest(row, proof_media)
            })
            .collect(),
    ))
}

pub async fn submit_quest(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(quest_id): Path<Uuid>,
    Json(payload): Json<SubmitQuestRequest>,
) -> AppResult<Json<QuestResponse>> {
    if claims.guild_role != GuildRole::Member {
        return Err(AppError::Forbidden(
            "only guild members can submit quest completion".into(),
        ));
    }

    let mut model = quest::Entity::find_by_id(quest_id)
        .filter(quest::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("quest not found".into()))?;

    if let Some(assigned_hunter_id) = model.assigned_hunter_id
        && assigned_hunter_id != claims.sub
    {
        return Err(AppError::Forbidden(
            "quest is assigned to another member".into(),
        ));
    }

    if model.status != QuestStatus::Available {
        return Err(AppError::BadRequest(
            "quest must be in available status to submit".into(),
        ));
    }

    let today = Utc::now().date_naive();
    if model.category == QuestCategory::Habit
        && already_completed_in_cycle(model.last_completed_at, model.cadence.as_ref(), today)
    {
        return Err(AppError::BadRequest(
            "habit has already been completed in the current cycle".into(),
        ));
    }

    let now = Utc::now();
    let mut active: quest::ActiveModel = model.into();
    active.status = Set(QuestStatus::PendingReview);
    active.proof_note = Set(normalize_optional_text(payload.proof_note));
    active.proof_submitted_at = Set(Some(now.into()));
    active.last_review_note = Set(None);
    active.updated_at = Set(now.into());
    model = active.update(&state.db).await?;
    let proof_media = load_quest_proof_media_for(&state.db, model.id).await?;
    Ok(Json(map_quest(model, proof_media)))
}

pub async fn upload_quest_proof_media(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Path(quest_id): Path<Uuid>,
    mut multipart: Multipart,
) -> AppResult<(StatusCode, Json<QuestProofMediaResponse>)> {
    if claims.guild_role != GuildRole::Member {
        return Err(AppError::Forbidden(
            "only guild members can upload habit proof media".into(),
        ));
    }

    let quest = quest::Entity::find_by_id(quest_id)
        .filter(quest::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("quest not found".into()))?;

    if let Some(assigned_hunter_id) = quest.assigned_hunter_id
        && assigned_hunter_id != claims.sub
    {
        return Err(AppError::Forbidden(
            "quest is assigned to another member".into(),
        ));
    }

    if quest.status != QuestStatus::Available {
        return Err(AppError::BadRequest(
            "proof media can only be uploaded while the habit is open".into(),
        ));
    }

    let mut payload: Option<(Vec<u8>, Option<String>, String)> = None;
    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|err| AppError::BadRequest(format!("invalid multipart payload: {err}")))?
    {
        if field.file_name().is_none() {
            continue;
        }

        let original_filename = field.file_name().map(str::to_string);
        let mime_type = normalize_image_mime(
            field.content_type().map(str::to_string),
            original_filename.as_deref(),
        )?;
        let bytes = field
            .bytes()
            .await
            .map_err(|err| AppError::BadRequest(format!("failed to read uploaded file: {err}")))?;
        if bytes.is_empty() {
            return Err(AppError::BadRequest(
                "uploaded proof image must not be empty".into(),
            ));
        }
        if bytes.len() > max_proof_media_bytes() {
            return Err(AppError::BadRequest(
                "proof image must be 8 MB or smaller".into(),
            ));
        }
        payload = Some((bytes.to_vec(), original_filename, mime_type));
        break;
    }

    let Some((bytes, original_filename, mime_type)) = payload else {
        return Err(AppError::BadRequest(
            "multipart payload must include an image file".into(),
        ));
    };

    let media_id = Uuid::new_v4();
    let extension = preferred_media_extension(original_filename.as_deref(), &mime_type);
    let storage_key = format!("quest-proof/{quest_id}/{media_id}{extension}");
    let file_path = proof_upload_root().join(&storage_key);
    if let Some(parent) = file_path.parent() {
        tokio::fs::create_dir_all(parent).await.map_err(|err| {
            AppError::ServiceUnavailable(format!("failed to prepare upload directory: {err}"))
        })?;
    }
    tokio::fs::write(&file_path, &bytes).await.map_err(|err| {
        AppError::ServiceUnavailable(format!("failed to store uploaded proof image: {err}"))
    })?;

    let created_at = Utc::now();
    let created = quest_proof_media::ActiveModel {
        id: Set(media_id),
        quest_id: Set(quest.id),
        guild_id: Set(claims.guild_id),
        uploaded_by_hunter_id: Set(claims.sub),
        storage_key: Set(storage_key.clone()),
        original_filename: Set(original_filename),
        mime_type: Set(mime_type.clone()),
        byte_size: Set(bytes.len() as i64),
        created_at: Set(created_at.into()),
    };

    let created = match created.insert(&state.db).await {
        Ok(model) => model,
        Err(err) => {
            let _ = tokio::fs::remove_file(&file_path).await;
            return Err(err.into());
        }
    };

    Ok((StatusCode::CREATED, Json(map_proof_media(created))))
}

pub async fn get_quest_proof_media_content(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Path(media_id): Path<Uuid>,
) -> AppResult<impl IntoResponse> {
    let media = quest_proof_media::Entity::find_by_id(media_id)
        .filter(quest_proof_media::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("proof media not found".into()))?;

    let file_path = proof_upload_root().join(&media.storage_key);
    let bytes = tokio::fs::read(&file_path)
        .await
        .map_err(|_| AppError::NotFound("proof media content not found".into()))?;

    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(&media.mime_type)
            .unwrap_or_else(|_| HeaderValue::from_static("application/octet-stream")),
    );
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));

    Ok((headers, Body::from(bytes)))
}

pub async fn review_quest(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Path(quest_id): Path<Uuid>,
    Json(payload): Json<ReviewQuestRequest>,
) -> AppResult<Json<ReviewQuestResponse>> {
    require_guild_owner(&claims)?;
    let txn = state.db.begin().await?;
    let review_note = normalize_optional_text(payload.review_note);
    let now = Utc::now();
    let today = now.date_naive();

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
        quest_am.last_review_note = Set(review_note);
        quest_am.updated_at = Set(now.into());
        let updated_quest = quest_am.update(&txn).await?;
        let proof_media = load_quest_proof_media_for(&txn, updated_quest.id).await?;
        txn.commit().await?;
        return Ok(Json(ReviewQuestResponse {
            quest: map_quest(updated_quest, proof_media),
            hunter: None,
            reward: None,
        }));
    }

    let hunter_id = match payload
        .hunter_id
        .or(current_quest.assigned_hunter_id)
        .or(claims.hunter_id)
    {
        Some(id) => id,
        None => {
            return rollback(
                txn,
                AppError::BadRequest("hunter_id is required when approved=true".into()),
            )
            .await;
        }
    };

    let mut quest_am: quest::ActiveModel = current_quest.clone().into();
    quest_am.last_review_note = Set(review_note);
    quest_am.updated_at = Set(now.into());
    if current_quest.category == QuestCategory::Habit {
        let next_streak = next_habit_streak(
            current_quest.last_completed_at,
            current_quest.cadence.as_ref(),
            current_quest.streak_count,
            today,
        );
        let next_completions = current_quest
            .completions_count
            .checked_add(1)
            .ok_or_else(|| AppError::BadRequest("habit completions overflow".into()))?;
        quest_am.status = Set(QuestStatus::Available);
        quest_am.streak_count = Set(next_streak);
        quest_am.best_streak = Set(current_quest.best_streak.max(next_streak));
        quest_am.completions_count = Set(next_completions);
        quest_am.last_completed_at = Set(Some(today));
    } else {
        quest_am.status = Set(QuestStatus::Completed);
    }
    let updated_quest = quest_am.update(&txn).await?;
    let gained_xp = updated_quest.reward_xp;
    let gained_coins = updated_quest.reward_coins;

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
    let next_level = compute_level_from_xp(next_xp);
    let leveled_up = next_level > hunter_model.level;

    let mut hunter_am: hunter::ActiveModel = hunter_model.into();
    hunter_am.xp = Set(next_xp);
    hunter_am.coins = Set(next_coins);
    hunter_am.level = Set(next_level);
    let updated_hunter = hunter_am.update(&txn).await?;
    let reward_event_id = Uuid::new_v4();

    hunter_reward_ledger::ActiveModel {
        id: Set(reward_event_id),
        hunter_id: Set(updated_hunter.id),
        quest_id: Set(Some(updated_quest.id)),
        item_id: Set(None),
        idempotency_key: Set(None),
        event_type: Set(LedgerEventType::QuestReward),
        stat_category: Set(updated_quest.stat_category.clone()),
        gained_xp: Set(gained_xp),
        gained_coins: Set(gained_coins),
        created_at: Set(Utc::now().into()),
    }
    .insert(&txn)
    .await?;

    let proof_media = load_quest_proof_media_for(&txn, updated_quest.id).await?;
    txn.commit().await?;

    Ok(Json(ReviewQuestResponse {
        quest: map_quest(updated_quest, proof_media),
        hunter: Some(HunterRewardResponse {
            id: updated_hunter.id,
            guild_id: updated_hunter.guild_id,
            level: updated_hunter.level,
            xp: updated_hunter.xp,
            coins: updated_hunter.coins,
        }),
        reward: Some(ReviewRewardEvent {
            reward_event_id,
            hunter_id: updated_hunter.id,
            gained_xp,
            gained_coins,
            leveled_up,
            new_level: updated_hunter.level,
        }),
    }))
}

async fn rollback<T>(txn: DatabaseTransaction, err: AppError) -> AppResult<T> {
    txn.rollback().await?;
    Err(err)
}

fn map_quest(model: quest::Model, proof_media: Vec<QuestProofMediaResponse>) -> QuestResponse {
    QuestResponse {
        id: model.id,
        guild_id: model.guild_id,
        title: model.title,
        description: model.description,
        reward_xp: model.reward_xp,
        reward_coins: model.reward_coins,
        stat_category: model.stat_category,
        category: model.category,
        assigned_hunter_id: model.assigned_hunter_id,
        created_by_hunter_id: model.created_by_hunter_id,
        cadence: model.cadence,
        streak_count: model.streak_count,
        best_streak: model.best_streak,
        completions_count: model.completions_count,
        proof_note: model.proof_note,
        proof_submitted_at: model.proof_submitted_at,
        last_completed_at: model.last_completed_at,
        last_review_note: model.last_review_note,
        proof_media,
        updated_at: model.updated_at,
        status: model.status,
    }
}

fn map_proof_media(model: quest_proof_media::Model) -> QuestProofMediaResponse {
    QuestProofMediaResponse {
        id: model.id,
        quest_id: model.quest_id,
        original_filename: model.original_filename,
        mime_type: model.mime_type,
        byte_size: model.byte_size,
        content_path: format!("/api/v1/quests/proof-media/{}/content", model.id),
        created_at: model.created_at,
    }
}

fn default_quest_stat_category() -> QuestStatCategory {
    QuestStatCategory::None
}

fn default_quest_category() -> QuestCategory {
    QuestCategory::Chore
}

fn compute_level_from_xp(xp: i32) -> i32 {
    (xp.max(0) / 100) + 1
}

fn normalize_optional_text(value: Option<String>) -> Option<String> {
    value
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
}

fn normalize_image_mime(
    raw_mime_type: Option<String>,
    original_filename: Option<&str>,
) -> AppResult<String> {
    let normalized = raw_mime_type
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_ascii_lowercase)
        .or_else(|| guess_mime_from_filename(original_filename))
        .ok_or_else(|| AppError::BadRequest("proof image type could not be determined".into()))?;

    if normalized.starts_with("image/") {
        return Ok(normalized);
    }

    Err(AppError::BadRequest(
        "only image uploads are supported for habit proof".into(),
    ))
}

fn guess_mime_from_filename(original_filename: Option<&str>) -> Option<String> {
    let file_name = original_filename?.trim().to_ascii_lowercase();
    if file_name.ends_with(".png") {
        return Some("image/png".to_string());
    }
    if file_name.ends_with(".jpg") || file_name.ends_with(".jpeg") {
        return Some("image/jpeg".to_string());
    }
    if file_name.ends_with(".webp") {
        return Some("image/webp".to_string());
    }
    if file_name.ends_with(".gif") {
        return Some("image/gif".to_string());
    }
    if file_name.ends_with(".heic") || file_name.ends_with(".heif") {
        return Some("image/heic".to_string());
    }
    None
}

fn preferred_media_extension(original_filename: Option<&str>, mime_type: &str) -> &'static str {
    let mime_type = mime_type.trim().to_ascii_lowercase();
    if let Some(filename) = original_filename {
        let normalized = filename.trim().to_ascii_lowercase();
        if normalized.ends_with(".png") {
            return ".png";
        }
        if normalized.ends_with(".jpg") || normalized.ends_with(".jpeg") {
            return ".jpg";
        }
        if normalized.ends_with(".webp") {
            return ".webp";
        }
        if normalized.ends_with(".gif") {
            return ".gif";
        }
        if normalized.ends_with(".heic") || normalized.ends_with(".heif") {
            return ".heic";
        }
    }

    match mime_type.as_str() {
        "image/png" => ".png",
        "image/webp" => ".webp",
        "image/gif" => ".gif",
        "image/heic" | "image/heif" => ".heic",
        _ => ".jpg",
    }
}

fn max_proof_media_bytes() -> usize {
    8 * 1024 * 1024
}

fn proof_upload_root() -> PathBuf {
    std::env::var("BIT_BOND_UPLOAD_DIR")
        .ok()
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("output/uploads"))
}

async fn load_quest_proof_media_for<C: ConnectionTrait>(
    db: &C,
    quest_id: Uuid,
) -> AppResult<Vec<QuestProofMediaResponse>> {
    let mut map = load_quest_proof_media_map(db, &[quest_id]).await?;
    Ok(map.remove(&quest_id).unwrap_or_default())
}

async fn load_quest_proof_media_map<C: ConnectionTrait>(
    db: &C,
    quest_ids: &[Uuid],
) -> AppResult<HashMap<Uuid, Vec<QuestProofMediaResponse>>> {
    if quest_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let rows = quest_proof_media::Entity::find()
        .filter(quest_proof_media::Column::QuestId.is_in(quest_ids.iter().copied()))
        .order_by_asc(quest_proof_media::Column::CreatedAt)
        .order_by_asc(quest_proof_media::Column::Id)
        .all(db)
        .await?;

    let mut grouped = HashMap::<Uuid, Vec<QuestProofMediaResponse>>::new();
    for row in rows {
        grouped
            .entry(row.quest_id)
            .or_default()
            .push(map_proof_media(row));
    }
    Ok(grouped)
}

fn normalize_cadence(
    category: QuestCategory,
    cadence: Option<HabitCadence>,
) -> AppResult<Option<HabitCadence>> {
    if category == QuestCategory::Habit {
        return Ok(Some(cadence.unwrap_or(HabitCadence::Daily)));
    }
    if cadence.is_some() {
        return Err(AppError::BadRequest(
            "cadence is only supported for habit challenges".into(),
        ));
    }
    Ok(None)
}

fn already_completed_in_cycle(
    last_completed_at: Option<NaiveDate>,
    cadence: Option<&HabitCadence>,
    today: NaiveDate,
) -> bool {
    let Some(last_completed_at) = last_completed_at else {
        return false;
    };
    cadence_anchor(cadence, last_completed_at) == cadence_anchor(cadence, today)
}

fn next_habit_streak(
    last_completed_at: Option<NaiveDate>,
    cadence: Option<&HabitCadence>,
    current_streak: i32,
    today: NaiveDate,
) -> i32 {
    let Some(last_completed_at) = last_completed_at else {
        return 1;
    };
    let last_anchor = cadence_anchor(cadence, last_completed_at);
    let today_anchor = cadence_anchor(cadence, today);
    let expected_previous = previous_cadence_anchor(cadence, today_anchor);
    if last_anchor == expected_previous {
        return current_streak.max(0).saturating_add(1);
    }
    if last_anchor < expected_previous {
        return 1;
    }
    1
}

fn cadence_anchor(cadence: Option<&HabitCadence>, day: NaiveDate) -> NaiveDate {
    match cadence {
        Some(HabitCadence::Weekly) => day
            .checked_sub_days(Days::new(day.weekday().num_days_from_monday() as u64))
            .unwrap_or(day),
        _ => day,
    }
}

fn previous_cadence_anchor(cadence: Option<&HabitCadence>, day: NaiveDate) -> NaiveDate {
    match cadence {
        Some(HabitCadence::Weekly) => day.checked_sub_days(Days::new(7)).unwrap_or(day),
        _ => day.checked_sub_days(Days::new(1)).unwrap_or(day),
    }
}

#[cfg(test)]
#[path = "quests_tests.rs"]
mod tests;
