use axum::{
    Json,
    extract::{Path, Query, State},
};
use chrono::Utc;
use entity::{
    guild_item, hunter, hunter_inventory,
    hunter_reward_ledger::{self, LedgerEventType},
    quest::QuestStatCategory,
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, DatabaseBackend,
    DatabaseConnection, DatabaseTransaction, DbErr, EntityTrait, QueryFilter, QueryOrder, SqlErr,
    Statement, TransactionTrait,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::{AuthClaims, GuildMasterClaims},
    state::AppState,
};

#[derive(Debug, Serialize, Clone)]
pub struct ShopItemResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub cost_coins: i32,
    pub icon_tag: String,
    pub is_active: bool,
}

#[derive(Debug, Deserialize)]
pub struct BuyItemRequest {
    pub idempotency_key: Uuid,
}

#[derive(Debug, Deserialize, Default)]
pub struct ListShopItemsQuery {
    pub include_inactive: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct CreateShopItemRequest {
    pub name: String,
    pub description: Option<String>,
    pub cost_coins: i32,
    pub icon_tag: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateShopItemRequest {
    pub name: String,
    pub description: Option<String>,
    pub cost_coins: i32,
    pub icon_tag: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct BuyItemResponse {
    pub ledger_event_id: Uuid,
    pub idempotency_key: Uuid,
    pub hunter_id: Uuid,
    pub item: ShopItemResponse,
    pub spent_coins: i32,
    pub remaining_coins: i32,
    pub inventory_quantity: i32,
    pub replayed: bool,
}

pub async fn list_shop_items(
    AuthClaims(claims): AuthClaims,
    Query(query): Query<ListShopItemsQuery>,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<ShopItemResponse>>> {
    let mut finder =
        guild_item::Entity::find().filter(guild_item::Column::GuildId.eq(claims.guild_id));
    let can_include_inactive = claims.guild_role == crate::jwt::GuildRole::Master
        && query.include_inactive.unwrap_or(false);
    if !can_include_inactive {
        finder = finder.filter(guild_item::Column::IsActive.eq(true));
    }
    let rows = finder
        .order_by_asc(guild_item::Column::CostCoins)
        .order_by_asc(guild_item::Column::Name)
        .all(&state.db)
        .await?;

    Ok(Json(rows.into_iter().map(map_shop_item).collect()))
}

pub async fn create_shop_item(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Json(payload): Json<CreateShopItemRequest>,
) -> AppResult<(axum::http::StatusCode, Json<ShopItemResponse>)> {
    let (name, description, cost_coins, icon_tag) = normalize_shop_item_payload(
        payload.name,
        payload.description,
        payload.cost_coins,
        payload.icon_tag,
    )?;

    let created = guild_item::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(claims.guild_id),
        name: Set(name),
        description: Set(description),
        cost_coins: Set(cost_coins),
        icon_tag: Set(icon_tag),
        is_active: Set(true),
    }
    .insert(&state.db)
    .await
    .map_err(map_shop_unique_conflict)?;

    Ok((
        axum::http::StatusCode::CREATED,
        Json(map_shop_item(created)),
    ))
}

pub async fn update_shop_item(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Path(item_id): Path<Uuid>,
    Json(payload): Json<UpdateShopItemRequest>,
) -> AppResult<Json<ShopItemResponse>> {
    let model = guild_item::Entity::find_by_id(item_id)
        .filter(guild_item::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("shop item not found".into()))?;
    let (name, description, cost_coins, icon_tag) = normalize_shop_item_payload(
        payload.name,
        payload.description,
        payload.cost_coins,
        payload.icon_tag,
    )?;

    let mut am: guild_item::ActiveModel = model.into();
    am.name = Set(name);
    am.description = Set(description);
    am.cost_coins = Set(cost_coins);
    am.icon_tag = Set(icon_tag);

    let updated = am
        .update(&state.db)
        .await
        .map_err(map_shop_unique_conflict)?;
    Ok(Json(map_shop_item(updated)))
}

pub async fn deactivate_shop_item(
    GuildMasterClaims(claims): GuildMasterClaims,
    State(state): State<AppState>,
    Path(item_id): Path<Uuid>,
) -> AppResult<Json<ShopItemResponse>> {
    let model = guild_item::Entity::find_by_id(item_id)
        .filter(guild_item::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("shop item not found".into()))?;

    let mut am: guild_item::ActiveModel = model.into();
    am.is_active = Set(false);
    let updated = am.update(&state.db).await?;
    Ok(Json(map_shop_item(updated)))
}

pub async fn buy_item(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Path(item_id): Path<Uuid>,
    Json(payload): Json<BuyItemRequest>,
) -> AppResult<Json<BuyItemResponse>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("token missing hunter_id".into()))?;
    let item = guild_item::Entity::find_by_id(item_id)
        .filter(guild_item::Column::GuildId.eq(claims.guild_id))
        .filter(guild_item::Column::IsActive.eq(true))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("shop item not found".into()))?;

    let item_response = map_shop_item(item.clone());
    let txn = state.db.begin().await?;

    if let Some(existing) =
        find_purchase_by_idempotency(&txn, hunter_id, payload.idempotency_key).await?
    {
        if existing.item_id != Some(item.id) {
            return rollback(
                txn,
                AppError::Conflict("idempotency_key already used for another item".into()),
            )
            .await;
        }
        let replay = build_replay_response(
            &txn,
            &item_response,
            hunter_id,
            payload.idempotency_key,
            existing,
        )
        .await?;
        txn.commit().await?;
        return Ok(Json(replay));
    }

    let current_coins = lock_hunter_coins(&txn, hunter_id, claims.guild_id).await?;
    if current_coins < item.cost_coins {
        return rollback(txn, AppError::BadRequest("coins not enough".into())).await;
    }

    let remaining_coins = current_coins - item.cost_coins;
    set_hunter_coins(&txn, hunter_id, remaining_coins).await?;
    let inventory_quantity = upsert_inventory_and_get_quantity(&txn, hunter_id, item.id).await?;
    let ledger_event_id = Uuid::new_v4();

    let inserted = hunter_reward_ledger::ActiveModel {
        id: Set(ledger_event_id),
        hunter_id: Set(hunter_id),
        quest_id: Set(None),
        item_id: Set(Some(item.id)),
        idempotency_key: Set(Some(payload.idempotency_key)),
        event_type: Set(LedgerEventType::ShopPurchase),
        stat_category: Set(QuestStatCategory::None),
        gained_xp: Set(0),
        gained_coins: Set(-item.cost_coins),
        created_at: Set(Utc::now().into()),
    }
    .insert(&txn)
    .await;

    match inserted {
        Ok(_) => {
            txn.commit().await?;
            Ok(Json(BuyItemResponse {
                ledger_event_id,
                idempotency_key: payload.idempotency_key,
                hunter_id,
                item: item_response,
                spent_coins: item.cost_coins,
                remaining_coins,
                inventory_quantity,
                replayed: false,
            }))
        }
        Err(err) if is_ledger_idempotency_unique_violation(&err) => {
            txn.rollback().await?;
            let replay = lookup_replay_response(
                &state.db,
                &item_response,
                hunter_id,
                payload.idempotency_key,
            )
            .await?;
            Ok(Json(replay))
        }
        Err(err) => Err(AppError::Database(err)),
    }
}

async fn lookup_replay_response(
    db: &DatabaseConnection,
    item: &ShopItemResponse,
    hunter_id: Uuid,
    idempotency_key: Uuid,
) -> AppResult<BuyItemResponse> {
    let existing = find_purchase_by_idempotency(db, hunter_id, idempotency_key)
        .await?
        .ok_or_else(|| AppError::Conflict("idempotency replay record is missing".into()))?;
    if existing.item_id != Some(item.id) {
        return Err(AppError::Conflict(
            "idempotency_key already used for another item".into(),
        ));
    }
    build_replay_response(db, item, hunter_id, idempotency_key, existing).await
}

async fn build_replay_response<C>(
    db: &C,
    item: &ShopItemResponse,
    hunter_id: Uuid,
    idempotency_key: Uuid,
    existing: hunter_reward_ledger::Model,
) -> AppResult<BuyItemResponse>
where
    C: ConnectionTrait,
{
    let hunter_model = hunter::Entity::find_by_id(hunter_id)
        .one(db)
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;
    let inventory = hunter_inventory::Entity::find()
        .filter(hunter_inventory::Column::HunterId.eq(hunter_id))
        .filter(hunter_inventory::Column::ItemId.eq(item.id))
        .one(db)
        .await?;

    Ok(BuyItemResponse {
        ledger_event_id: existing.id,
        idempotency_key,
        hunter_id,
        item: item.clone(),
        spent_coins: (-existing.gained_coins).max(0),
        remaining_coins: hunter_model.coins,
        inventory_quantity: inventory.map_or(0, |row| row.quantity),
        replayed: true,
    })
}

async fn find_purchase_by_idempotency<C>(
    db: &C,
    hunter_id: Uuid,
    idempotency_key: Uuid,
) -> Result<Option<hunter_reward_ledger::Model>, DbErr>
where
    C: ConnectionTrait,
{
    hunter_reward_ledger::Entity::find()
        .filter(hunter_reward_ledger::Column::HunterId.eq(hunter_id))
        .filter(hunter_reward_ledger::Column::IdempotencyKey.eq(Some(idempotency_key)))
        .filter(hunter_reward_ledger::Column::EventType.eq(LedgerEventType::ShopPurchase))
        .one(db)
        .await
}

async fn lock_hunter_coins(
    txn: &DatabaseTransaction,
    hunter_id: Uuid,
    guild_id: Uuid,
) -> AppResult<i32> {
    let row = txn
        .query_one(Statement::from_sql_and_values(
            DatabaseBackend::Postgres,
            r#"SELECT coins FROM hunters WHERE id = $1 AND guild_id = $2 FOR UPDATE"#,
            vec![hunter_id.into(), guild_id.into()],
        ))
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;

    row.try_get("", "coins")
        .map_err(|err| AppError::BadRequest(format!("invalid hunter coins value: {err}")))
}

async fn set_hunter_coins(txn: &DatabaseTransaction, hunter_id: Uuid, coins: i32) -> AppResult<()> {
    txn.execute(Statement::from_sql_and_values(
        DatabaseBackend::Postgres,
        r#"UPDATE hunters SET coins = $1 WHERE id = $2"#,
        vec![coins.into(), hunter_id.into()],
    ))
    .await?;
    Ok(())
}

async fn upsert_inventory_and_get_quantity(
    txn: &DatabaseTransaction,
    hunter_id: Uuid,
    item_id: Uuid,
) -> AppResult<i32> {
    let row = txn
        .query_one(Statement::from_sql_and_values(
            DatabaseBackend::Postgres,
            r#"
            INSERT INTO hunter_inventories (id, hunter_id, item_id, quantity, updated_at)
            VALUES ($1, $2, $3, 1, CURRENT_TIMESTAMP)
            ON CONFLICT (hunter_id, item_id)
            DO UPDATE SET quantity = hunter_inventories.quantity + 1, updated_at = CURRENT_TIMESTAMP
            RETURNING quantity
            "#,
            vec![Uuid::new_v4().into(), hunter_id.into(), item_id.into()],
        ))
        .await?
        .ok_or_else(|| AppError::Database(DbErr::Custom("inventory upsert failed".into())))?;

    row.try_get("", "quantity")
        .map_err(|err| AppError::BadRequest(format!("invalid inventory quantity: {err}")))
}

async fn rollback<T>(txn: DatabaseTransaction, err: AppError) -> AppResult<T> {
    txn.rollback().await?;
    Err(err)
}

fn map_shop_item(model: guild_item::Model) -> ShopItemResponse {
    ShopItemResponse {
        id: model.id,
        guild_id: model.guild_id,
        name: model.name,
        description: model.description,
        cost_coins: model.cost_coins,
        icon_tag: model.icon_tag,
        is_active: model.is_active,
    }
}

fn normalize_shop_item_payload(
    name: String,
    description: Option<String>,
    cost_coins: i32,
    icon_tag: String,
) -> AppResult<(String, Option<String>, i32, String)> {
    let normalized_name = name.trim();
    if normalized_name.is_empty() {
        return Err(AppError::BadRequest("name must not be empty".into()));
    }
    if normalized_name.chars().count() > 64 {
        return Err(AppError::BadRequest("name must be <= 64 chars".into()));
    }
    if cost_coins < 0 {
        return Err(AppError::BadRequest("cost_coins must be >= 0".into()));
    }
    let normalized_icon = icon_tag.trim().to_ascii_uppercase();
    if !matches!(
        normalized_icon.as_str(),
        "TICKET" | "POTION" | "TOY" | "FOOD" | "SCROLL"
    ) {
        return Err(AppError::BadRequest(
            "icon_tag must be one of TICKET, POTION, TOY, FOOD, SCROLL".into(),
        ));
    }
    let normalized_description = description
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(ToOwned::to_owned);

    Ok((
        normalized_name.to_string(),
        normalized_description,
        cost_coins,
        normalized_icon,
    ))
}

fn map_shop_unique_conflict(err: DbErr) -> AppError {
    match err.sql_err() {
        Some(SqlErr::UniqueConstraintViolation(message))
            if message.contains("idx_guild_items_guild_name_unique")
                || message.contains("guild_items_guild_id_name_key")
                || message.contains("(guild_id, name)") =>
        {
            AppError::Conflict("shop item name already exists in this guild".into())
        }
        _ => AppError::Database(err),
    }
}

fn is_ledger_idempotency_unique_violation(err: &DbErr) -> bool {
    match err.sql_err() {
        Some(SqlErr::UniqueConstraintViolation(message)) => [
            "idx_hunter_reward_ledger_hunter_idempotency",
            "hunter_reward_ledger_hunter_idempotency",
            "(hunter_id, idempotency_key)",
        ]
        .iter()
        .any(|candidate| message.contains(candidate)),
        _ => false,
    }
}

#[cfg(test)]
#[path = "shop_tests.rs"]
mod tests;
