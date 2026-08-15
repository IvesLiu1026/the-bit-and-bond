use axum::{
    Json,
    extract::{Path, State},
};
use chrono::Utc;
use entity::{chat_message, guild_item, hunter, hunter_inventory};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, DatabaseBackend, EntityTrait,
    QueryFilter, QueryOrder, Statement, TransactionTrait,
};
use serde::Serialize;
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::AuthClaims,
    state::AppState,
};

use super::chat::default_guild_chat_room;

#[derive(Debug, Serialize, Clone)]
pub struct InventoryItemResponse {
    pub item_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub icon_tag: String,
    pub quantity: i32,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, Clone)]
pub struct UseInventoryItemResponse {
    pub item_id: Uuid,
    pub item_name: String,
    pub remaining_quantity: i32,
    pub system_message: String,
    pub chat_message_id: Uuid,
}

pub async fn list_inventory(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
) -> AppResult<Json<Vec<InventoryItemResponse>>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("token missing hunter_id".into()))?;

    let rows = hunter_inventory::Entity::find()
        .filter(hunter_inventory::Column::HunterId.eq(hunter_id))
        .filter(hunter_inventory::Column::Quantity.gt(0))
        .find_also_related(guild_item::Entity)
        .order_by_desc(hunter_inventory::Column::UpdatedAt)
        .all(&state.db)
        .await?;

    let mut items = Vec::with_capacity(rows.len());
    for (inventory, item) in rows {
        let Some(item) = item else {
            continue;
        };
        if item.guild_id != claims.guild_id {
            continue;
        }
        items.push(InventoryItemResponse {
            item_id: item.id,
            name: item.name,
            description: item.description,
            icon_tag: item.icon_tag,
            quantity: inventory.quantity,
            updated_at: inventory.updated_at.with_timezone(&Utc),
        });
    }

    Ok(Json(items))
}

pub async fn use_inventory_item(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Path(item_id): Path<Uuid>,
) -> AppResult<Json<UseInventoryItemResponse>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("token missing hunter_id".into()))?;

    let txn = state.db.begin().await?;

    let hunter_model = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&txn)
        .await?
        .ok_or_else(|| AppError::NotFound("hunter not found".into()))?;

    let item_model = guild_item::Entity::find_by_id(item_id)
        .filter(guild_item::Column::GuildId.eq(claims.guild_id))
        .one(&txn)
        .await?
        .ok_or_else(|| AppError::NotFound("item not found in current guild".into()))?;

    let row = txn
        .query_one(Statement::from_sql_and_values(
            DatabaseBackend::Postgres,
            r#"
            SELECT quantity
            FROM hunter_inventories
            WHERE hunter_id = $1 AND item_id = $2
            FOR UPDATE
            "#,
            vec![hunter_id.into(), item_id.into()],
        ))
        .await?
        .ok_or_else(|| AppError::BadRequest("item not found in inventory".into()))?;

    let quantity: i32 = row
        .try_get("", "quantity")
        .map_err(|err| AppError::BadRequest(format!("invalid inventory quantity: {err}")))?;
    if quantity <= 0 {
        txn.rollback().await?;
        return Err(AppError::BadRequest("item quantity is empty".into()));
    }

    let remaining_quantity = quantity - 1;
    txn.execute(Statement::from_sql_and_values(
        DatabaseBackend::Postgres,
        r#"
        UPDATE hunter_inventories
        SET quantity = $1, updated_at = CURRENT_TIMESTAMP
        WHERE hunter_id = $2 AND item_id = $3
        "#,
        vec![remaining_quantity.into(), hunter_id.into(), item_id.into()],
    ))
    .await?;

    let room_id = default_guild_chat_room(claims.guild_id);
    let system_message = format!(
        "[系統] 玩家 {} 剛剛使用了「{}」！",
        hunter_model.name, item_model.name
    );

    let chat = chat_message::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(claims.guild_id),
        sender_hunter_id: Set(hunter_id),
        room_id: Set(room_id.clone()),
        client_message_id: Set(Uuid::new_v4()),
        content: Set(system_message.clone()),
        sent_at: Set(Utc::now().into()),
    }
    .insert(&txn)
    .await?;

    txn.commit().await?;
    state
        .presence
        .publish_chat_notice(claims.guild_id, room_id, chat.id)
        .await;

    Ok(Json(UseInventoryItemResponse {
        item_id,
        item_name: item_model.name,
        remaining_quantity,
        system_message,
        chat_message_id: chat.id,
    }))
}

#[cfg(test)]
mod tests {
    use std::{error::Error, sync::Arc};

    use axum::extract::State;
    use entity::{chat_message, guild, guild_item, hunter, hunter_inventory, user};
    use migration::MigratorTrait;
    use sea_orm::{
        ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, Database,
        DatabaseBackend, EntityTrait, QueryFilter, Statement,
    };
    use tokio::sync::Barrier;
    use uuid::Uuid;

    use crate::{
        extractors::AuthClaims,
        jwt::{AuthRole, Claims, GuildRole, JwtService},
        state::AppState,
    };

    use super::{list_inventory, use_inventory_item};

    #[tokio::test]
    async fn list_inventory_returns_positive_quantity_only() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, claims, item_a, _item_b) = ctx.seed_inventory("list").await?;

        let items = list_inventory(claims, State(state.clone())).await?.0;
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].item_id, item_a);
        assert_eq!(items[0].quantity, 2);

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn use_inventory_decrements_and_writes_system_chat() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, claims, item_a, _item_b) = ctx.seed_inventory("use_ok").await?;
        let hunter_id = claims.0.sub;

        let result = use_inventory_item(claims, State(state.clone()), axum::extract::Path(item_a))
            .await?
            .0;

        assert_eq!(result.item_id, item_a);
        assert_eq!(result.remaining_quantity, 1);
        assert!(result.system_message.contains("[系統]"));
        assert!(result.system_message.contains("冒險補給藥水"));

        let inventory = hunter_inventory::Entity::find()
            .filter(hunter_inventory::Column::HunterId.eq(hunter_id))
            .filter(hunter_inventory::Column::ItemId.eq(item_a))
            .one(&state.db)
            .await?
            .expect("inventory exists");
        assert_eq!(inventory.quantity, 1);

        let msg = chat_message::Entity::find_by_id(result.chat_message_id)
            .one(&state.db)
            .await?
            .expect("chat message exists");
        assert!(msg.content.contains("使用了"));

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn use_inventory_rejects_empty_quantity() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, claims, _item_a, item_b) = ctx.seed_inventory("use_empty").await?;

        let err = use_inventory_item(claims, State(state.clone()), axum::extract::Path(item_b))
            .await
            .expect_err("empty inventory should fail");
        assert!(matches!(err, crate::error::AppError::BadRequest(_)));

        ctx.cleanup().await?;
        Ok(())
    }

    #[tokio::test]
    async fn concurrent_use_only_allows_single_success_when_quantity_is_one()
    -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, claims, item_a, _item_b) = ctx.seed_inventory("race").await?;
        let hunter_id = claims.0.sub;
        state
            .db
            .execute(Statement::from_sql_and_values(
                DatabaseBackend::Postgres,
                r#"UPDATE hunter_inventories SET quantity = 1 WHERE hunter_id = $1 AND item_id = $2"#,
                vec![hunter_id.into(), item_a.into()],
            ))
            .await?;
        let barrier = Arc::new(Barrier::new(2));

        let state_a = state.clone();
        let claims_a = claims.clone();
        let b1 = barrier.clone();
        let task_a = tokio::spawn(async move {
            b1.wait().await;
            use_inventory_item(claims_a, State(state_a), axum::extract::Path(item_a)).await
        });

        let state_b = state.clone();
        let claims_b = claims.clone();
        let b2 = barrier.clone();
        let task_b = tokio::spawn(async move {
            b2.wait().await;
            use_inventory_item(claims_b, State(state_b), axum::extract::Path(item_a)).await
        });

        let result_a = task_a.await?;
        let result_b = task_b.await?;
        let success_count = i32::from(result_a.is_ok()) + i32::from(result_b.is_ok());
        assert_eq!(success_count, 1);
        let failure = if let Err(err) = result_a {
            err
        } else {
            result_b.expect_err("one request should fail")
        };
        assert!(matches!(failure, crate::error::AppError::BadRequest(_)));

        let inventory = hunter_inventory::Entity::find()
            .filter(hunter_inventory::Column::HunterId.eq(hunter_id))
            .filter(hunter_inventory::Column::ItemId.eq(item_a))
            .one(&state.db)
            .await?
            .expect("inventory exists");
        assert_eq!(inventory.quantity, 0);

        ctx.cleanup().await?;
        Ok(())
    }

    #[derive(Clone)]
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
            let db_name = format!("the_bit_and_bond_it_inventory_{}", Uuid::new_v4().simple());
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

        async fn seed_inventory(
            &self,
            suffix: &str,
        ) -> Result<(AppState, AuthClaims, Uuid, Uuid), Box<dyn Error>> {
            let user_id = Uuid::new_v4();
            let guild_id = Uuid::new_v4();
            let hunter_id = Uuid::new_v4();
            let item_a = Uuid::new_v4();
            let item_b = Uuid::new_v4();

            user::ActiveModel {
                id: Set(user_id),
                email: Set(format!("inventory-{suffix}@example.com")),
                password_hash: Set("$argon2id$fake$hash".to_string()),
                hunter_tag: Set(format!("ID-{}", suffix.to_ascii_uppercase())),
                current_role: Set("Explorer".to_string()),
                created_at: Set(chrono::Utc::now()),
            }
            .insert(&self.app_db)
            .await?;

            guild::ActiveModel {
                id: Set(guild_id),
                name: Set(format!("guild-{suffix}")),
                owner_id: Set(user_id),
                invite_code: Set(format!(
                    "I{}",
                    Uuid::new_v4().simple().to_string()[..5].to_ascii_uppercase()
                )),
            }
            .insert(&self.app_db)
            .await?;

            hunter::ActiveModel {
                id: Set(hunter_id),
                guild_id: Set(guild_id),
                user_id: Set(Some(user_id)),
                player_id: Set(format!("player_inventory_{suffix}")),
                name: Set(format!("inventory-player-{suffix}")),
                avatar_type: Set("rookie".to_string()),
                level: Set(1),
                xp: Set(0),
                coins: Set(30),
                pin_code: Set("$argon2id$seed".to_string()),
                guild_role: Set("member".to_string()),
                motto: Set(None),
            }
            .insert(&self.app_db)
            .await?;

            guild_item::ActiveModel {
                id: Set(item_a),
                guild_id: Set(guild_id),
                name: Set("冒險補給藥水".to_string()),
                description: Set(Some("補充體力".to_string())),
                cost_coins: Set(20),
                icon_tag: Set("POTION".to_string()),
                is_active: Set(true),
            }
            .insert(&self.app_db)
            .await?;

            guild_item::ActiveModel {
                id: Set(item_b),
                guild_id: Set(guild_id),
                name: Set("家庭電影夜".to_string()),
                description: Set(Some("週末活動".to_string())),
                cost_coins: Set(40),
                icon_tag: Set("FOOD".to_string()),
                is_active: Set(true),
            }
            .insert(&self.app_db)
            .await?;

            hunter_inventory::ActiveModel {
                id: Set(Uuid::new_v4()),
                hunter_id: Set(hunter_id),
                item_id: Set(item_a),
                quantity: Set(2),
                updated_at: Set(chrono::Utc::now().into()),
            }
            .insert(&self.app_db)
            .await?;

            hunter_inventory::ActiveModel {
                id: Set(Uuid::new_v4()),
                hunter_id: Set(hunter_id),
                item_id: Set(item_b),
                quantity: Set(0),
                updated_at: Set(chrono::Utc::now().into()),
            }
            .insert(&self.app_db)
            .await?;

            let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
            let state = AppState::new(self.app_db.clone(), jwt);
            let claims = AuthClaims(Claims {
                sub: hunter_id,
                role: AuthRole::Player,
                guild_role: GuildRole::Member,
                guild_id,
                hunter_id: Some(hunter_id),
                iat: 0,
                exp: 9_999_999_999,
            });

            Ok((state, claims, item_a, item_b))
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
