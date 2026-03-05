use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
};
use chrono::Utc;
use entity::{
    hunter,
    hunter_reward_ledger::{self, LedgerEventType},
    quest::{self, QuestStatCategory, QuestStatus},
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DatabaseTransaction, EntityTrait, QueryFilter,
    QueryOrder, TransactionTrait,
};
use serde::{Deserialize, Serialize};
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
    pub stat_category: QuestStatCategory,
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
        stat_category: Set(payload.stat_category),
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
    require_guild_owner(&claims)?;
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
            reward: None,
        }));
    }

    let hunter_id = match payload.hunter_id.or(claims.hunter_id) {
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

fn map_quest(model: quest::Model) -> QuestResponse {
    QuestResponse {
        id: model.id,
        guild_id: model.guild_id,
        title: model.title,
        description: model.description,
        reward_xp: model.reward_xp,
        reward_coins: model.reward_coins,
        stat_category: model.stat_category,
        status: model.status,
    }
}

fn default_quest_stat_category() -> QuestStatCategory {
    QuestStatCategory::None
}

fn compute_level_from_xp(xp: i32) -> i32 {
    (xp.max(0) / 100) + 1
}

#[cfg(test)]
#[path = "quests_tests.rs"]
mod tests;
