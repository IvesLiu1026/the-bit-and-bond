use std::{error::Error, sync::Arc};

use axum::{
    Json,
    body::Body,
    extract::Path,
    http::{Request, StatusCode},
};
use entity::{
    guild, guild_item, hunter, hunter_inventory, hunter_reward_ledger,
    hunter_reward_ledger::LedgerEventType, user,
};
use migration::MigratorTrait;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, Database, DatabaseBackend,
    DbErr, EntityTrait, PaginatorTrait, QueryFilter, Statement,
};
use tokio::sync::Barrier;
use uuid::Uuid;

use crate::{
    app::build_router,
    error::AppError,
    extractors::{AuthClaims, GuildMasterClaims},
    jwt::{AuthRole, Claims, GuildRole, JwtService},
    state::AppState,
};
use tower::ServiceExt;

use super::{
    BuyItemRequest, CreateShopItemRequest, ListShopItemsQuery, UpdateShopItemRequest, buy_item,
    create_shop_item, deactivate_shop_item, list_shop_items, update_shop_item,
};

#[tokio::test]
async fn list_items_is_scoped_to_current_guild() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, guild_a, member_claims) = ctx.seed_guild("scope_a", 100, 10).await?;
    let (_state_ignored, guild_b, _) = ctx.seed_guild("scope_b", 100, 10).await?;
    ctx.create_item(state.clone(), guild_a, "A 公會藥水", 15)
        .await?;

    guild_item::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(guild_b),
        name: Set("其他公會商品".to_string()),
        description: Set(None),
        cost_coins: Set(5),
        icon_tag: Set("POTION".to_string()),
        is_active: Set(true),
    }
    .insert(&state.db)
    .await?;

    let items = list_shop_items(
        member_claims,
        axum::extract::Query(ListShopItemsQuery::default()),
        axum::extract::State(state),
    )
    .await?
    .0;
    assert!(!items.is_empty());
    assert!(items.iter().all(|item| item.guild_id == guild_a));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn master_can_create_update_and_deactivate_item() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, guild_id, _member_claims) = ctx.seed_guild("admin_crud", 40, 10).await?;
    let master_claims = ctx.master_claims(guild_id).await?;

    let created = create_shop_item(
        master_claims.clone(),
        axum::extract::State(state.clone()),
        Json(CreateShopItemRequest {
            name: "  初學者木劍  ".to_string(),
            description: Some("新手練習用".to_string()),
            cost_coins: 25,
            icon_tag: "toy".to_string(),
        }),
    )
    .await?
    .1
    .0;
    assert_eq!(created.name, "初學者木劍");
    assert_eq!(created.guild_id, guild_id);
    assert!(created.is_active);

    let updated = update_shop_item(
        master_claims.clone(),
        axum::extract::State(state.clone()),
        Path(created.id),
        Json(UpdateShopItemRequest {
            name: "初學者鋼劍".to_string(),
            description: Some("升級版".to_string()),
            cost_coins: 45,
            icon_tag: "TICKET".to_string(),
        }),
    )
    .await?
    .0;
    assert_eq!(updated.name, "初學者鋼劍");
    assert_eq!(updated.cost_coins, 45);
    assert_eq!(updated.icon_tag, "TICKET");

    let deactivated = deactivate_shop_item(
        master_claims,
        axum::extract::State(state.clone()),
        Path(created.id),
    )
    .await?
    .0;
    assert!(!deactivated.is_active);

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn include_inactive_only_visible_to_master() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, guild_id, member_claims) = ctx.seed_guild("inactive_scope", 40, 10).await?;
    let master_claims = ctx.master_claims(guild_id).await?;
    let active_item = ctx
        .create_item(state.clone(), guild_id, "活躍商品", 10)
        .await?;
    let hidden_item = ctx
        .create_item(state.clone(), guild_id, "下架商品", 12)
        .await?;

    let _ = deactivate_shop_item(
        master_claims.clone(),
        axum::extract::State(state.clone()),
        Path(hidden_item.id),
    )
    .await?;

    let member_items = list_shop_items(
        member_claims,
        axum::extract::Query(ListShopItemsQuery {
            include_inactive: Some(true),
        }),
        axum::extract::State(state.clone()),
    )
    .await?
    .0;
    assert_eq!(member_items.len(), 1);
    assert_eq!(member_items[0].id, active_item.id);

    let master_items = list_shop_items(
        AuthClaims(master_claims.0),
        axum::extract::Query(ListShopItemsQuery {
            include_inactive: Some(true),
        }),
        axum::extract::State(state.clone()),
    )
    .await?
    .0;
    assert_eq!(master_items.len(), 2);
    assert!(master_items.iter().any(|it| !it.is_active));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn member_cannot_access_shop_management_routes() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, _guild_id, member_claims) = ctx.seed_guild("shop_guard", 80, 40).await?;
    let token = state
        .jwt
        .issue_player_token(
            member_claims.0.sub,
            member_claims.0.guild_id,
            GuildRole::Member,
        )?
        .access_token;
    let app = build_router(state, "*", true)?;

    let request = Request::builder()
        .method("POST")
        .uri("/api/v1/shop/items")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer {token}"))
        .body(Body::from(
            r#"{"name":"測試商品","description":"x","cost_coins":12,"icon_tag":"TOY"}"#,
        ))?;
    let response = app.oneshot(request).await?;
    assert_eq!(response.status(), StatusCode::FORBIDDEN);

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn buy_item_rejects_insufficient_coins() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, _guild, member_claims) = ctx.seed_guild("poor", 5, 20).await?;
    let item = ctx
        .create_item(state.clone(), member_claims.0.guild_id, "木劍", 20)
        .await?;
    let hunter_id = member_claims.0.sub;

    let err = buy_item(
        member_claims,
        axum::extract::State(state.clone()),
        Path(item.id),
        Json(BuyItemRequest {
            idempotency_key: Uuid::new_v4(),
        }),
    )
    .await
    .expect_err("insufficient coins should fail");
    assert!(matches!(err, AppError::BadRequest(_)));

    let hunter_after = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .expect("hunter exists");
    assert_eq!(hunter_after.coins, 5);
    let inventory_count = hunter_inventory::Entity::find()
        .filter(hunter_inventory::Column::HunterId.eq(hunter_id))
        .count(&state.db)
        .await?;
    assert_eq!(inventory_count, 0);

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn buy_item_rejects_cross_guild_item() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, _guild_a, member_a) = ctx.seed_guild("a", 120, 10).await?;
    let (_state_ignored, guild_b, _member_b) = ctx.seed_guild("b", 120, 10).await?;
    let item_b = ctx.create_item(state.clone(), guild_b, "禁品", 20).await?;

    let err = buy_item(
        member_a,
        axum::extract::State(state.clone()),
        Path(item_b.id),
        Json(BuyItemRequest {
            idempotency_key: Uuid::new_v4(),
        }),
    )
    .await
    .expect_err("cross-guild item access should fail");
    assert!(matches!(err, AppError::NotFound(_)));

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn buy_item_is_idempotent_by_key() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, guild_id, member_claims) = ctx.seed_guild("idem", 120, 10).await?;
    let item = ctx
        .create_item(state.clone(), guild_id, "旅行券", 30)
        .await?;
    let key = Uuid::new_v4();
    let hunter_id = member_claims.0.sub;

    let first = buy_item(
        member_claims.clone(),
        axum::extract::State(state.clone()),
        Path(item.id),
        Json(BuyItemRequest {
            idempotency_key: key,
        }),
    )
    .await?;
    assert!(!first.replayed);
    assert_eq!(first.remaining_coins, 90);
    assert_eq!(first.inventory_quantity, 1);

    let second = buy_item(
        member_claims,
        axum::extract::State(state.clone()),
        Path(item.id),
        Json(BuyItemRequest {
            idempotency_key: key,
        }),
    )
    .await?;
    assert!(second.replayed);
    assert_eq!(second.remaining_coins, 90);
    assert_eq!(second.inventory_quantity, 1);
    assert_eq!(second.ledger_event_id, first.ledger_event_id);

    let ledger_count = hunter_reward_ledger::Entity::find()
        .filter(hunter_reward_ledger::Column::HunterId.eq(hunter_id))
        .filter(hunter_reward_ledger::Column::EventType.eq(LedgerEventType::ShopPurchase))
        .count(&state.db)
        .await?;
    assert_eq!(ledger_count, 1);

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn concurrent_buy_double_spend_allows_single_success() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let (state, guild_id, member_claims) = ctx.seed_guild("race", 100, 10).await?;
    let item = ctx.create_item(state.clone(), guild_id, "巨劍", 80).await?;
    let hunter_id = member_claims.0.sub;
    let barrier = Arc::new(Barrier::new(2));

    let state_a = state.clone();
    let claims_a = member_claims.clone();
    let b1 = barrier.clone();
    let task_a = tokio::spawn(async move {
        b1.wait().await;
        buy_item(
            claims_a,
            axum::extract::State(state_a),
            Path(item.id),
            Json(BuyItemRequest {
                idempotency_key: Uuid::new_v4(),
            }),
        )
        .await
    });

    let state_b = state.clone();
    let claims_b = member_claims.clone();
    let b2 = barrier.clone();
    let task_b = tokio::spawn(async move {
        b2.wait().await;
        buy_item(
            claims_b,
            axum::extract::State(state_b),
            Path(item.id),
            Json(BuyItemRequest {
                idempotency_key: Uuid::new_v4(),
            }),
        )
        .await
    });

    let a = task_a.await?;
    let b = task_b.await?;
    let success_count = i32::from(a.is_ok()) + i32::from(b.is_ok());
    assert_eq!(success_count, 1);
    let failure = if let Err(err) = a {
        err
    } else {
        b.expect_err("one should fail")
    };
    assert!(matches!(failure, AppError::BadRequest(_)));

    let hunter_after = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .expect("hunter exists");
    assert_eq!(hunter_after.coins, 20);

    let inventory = hunter_inventory::Entity::find()
        .filter(hunter_inventory::Column::HunterId.eq(hunter_id))
        .filter(hunter_inventory::Column::ItemId.eq(item.id))
        .one(&state.db)
        .await?
        .expect("inventory exists");
    assert_eq!(inventory.quantity, 1);

    let ledger_count = hunter_reward_ledger::Entity::find()
        .filter(hunter_reward_ledger::Column::HunterId.eq(hunter_id))
        .filter(hunter_reward_ledger::Column::EventType.eq(LedgerEventType::ShopPurchase))
        .count(&state.db)
        .await?;
    assert_eq!(ledger_count, 1);

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
        let base_url = std::env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://chen:chen@127.0.0.1:5433/the_bit_and_bond".to_string());
        let db_name = format!("the_bit_and_bond_it_shop_{}", Uuid::new_v4().simple());
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

    async fn seed_guild(
        &self,
        suffix: &str,
        member_coins: i32,
        master_coins: i32,
    ) -> Result<(AppState, Uuid, AuthClaims), Box<dyn Error>> {
        let user_id = Uuid::new_v4();
        let guild_id = Uuid::new_v4();
        let master_hunter_id = Uuid::new_v4();
        let member_hunter_id = Uuid::new_v4();

        user::ActiveModel {
            id: Set(user_id),
            email: Set(format!("shop-master-{suffix}@example.com")),
            password_hash: Set("$argon2id$fake$hash".to_string()),
            hunter_tag: Set(format!("ID-{}M", suffix.to_ascii_uppercase())),
            current_role: Set("Guardian".to_string()),
            created_at: Set(chrono::Utc::now()),
        }
        .insert(&self.app_db)
        .await?;

        guild::ActiveModel {
            id: Set(guild_id),
            name: Set(format!("guild-{suffix}")),
            owner_id: Set(user_id),
            invite_code: Set(format!(
                "S{}",
                Uuid::new_v4().simple().to_string()[..5].to_ascii_uppercase()
            )),
        }
        .insert(&self.app_db)
        .await?;

        hunter::ActiveModel {
            id: Set(master_hunter_id),
            guild_id: Set(guild_id),
            user_id: Set(Some(user_id)),
            player_id: Set(format!("master_shop_{suffix}")),
            name: Set(format!("master-shop-{suffix}")),
            avatar_type: Set("master".to_string()),
            level: Set(1),
            xp: Set(0),
            coins: Set(master_coins),
            pin_code: Set("$argon2id$seed_master".to_string()),
            guild_role: Set("master".to_string()),
            motto: Set(None),
        }
        .insert(&self.app_db)
        .await?;

        hunter::ActiveModel {
            id: Set(member_hunter_id),
            guild_id: Set(guild_id),
            user_id: Set(None),
            player_id: Set(format!("member_shop_{suffix}")),
            name: Set(format!("member-shop-{suffix}")),
            avatar_type: Set("novice".to_string()),
            level: Set(1),
            xp: Set(0),
            coins: Set(member_coins),
            pin_code: Set("$argon2id$seed_member".to_string()),
            guild_role: Set("member".to_string()),
            motto: Set(None),
        }
        .insert(&self.app_db)
        .await?;

        let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
        let state = AppState::new(self.app_db.clone(), jwt);
        let member_claims = AuthClaims(Claims {
            sub: member_hunter_id,
            role: AuthRole::Player,
            guild_role: GuildRole::Member,
            guild_id,
            hunter_id: Some(member_hunter_id),
            iat: 0,
            exp: 9_999_999_999,
        });

        Ok((state, guild_id, member_claims))
    }

    async fn master_claims(&self, guild_id: Uuid) -> Result<GuildMasterClaims, Box<dyn Error>> {
        let model = hunter::Entity::find()
            .filter(hunter::Column::GuildId.eq(guild_id))
            .filter(hunter::Column::GuildRole.eq("master"))
            .one(&self.app_db)
            .await?
            .ok_or_else(|| "master hunter missing".to_string())?;
        Ok(GuildMasterClaims(Claims {
            sub: model.id,
            role: AuthRole::Player,
            guild_role: GuildRole::Master,
            guild_id,
            hunter_id: Some(model.id),
            iat: 0,
            exp: 9_999_999_999,
        }))
    }

    async fn create_item(
        &self,
        state: AppState,
        guild_id: Uuid,
        name: &str,
        cost_coins: i32,
    ) -> Result<guild_item::Model, DbErr> {
        guild_item::ActiveModel {
            id: Set(Uuid::new_v4()),
            guild_id: Set(guild_id),
            name: Set(name.to_string()),
            description: Set(Some(format!("{name} 描述"))),
            cost_coins: Set(cost_coins),
            icon_tag: Set("TICKET".to_string()),
            is_active: Set(true),
        }
        .insert(&state.db)
        .await
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
