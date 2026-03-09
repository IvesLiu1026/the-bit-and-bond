use axum::{Json, extract::State};
use chrono::Utc;
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, ConnectionTrait, Database, DatabaseBackend,
    EntityTrait, QueryFilter, Statement,
};
use std::error::Error;
use uuid::Uuid;

use crate::{firebase_identity::FirebaseIdentity, jwt::JwtService, state::AppState};
use entity::{guild, hunter, user};
use migration::MigratorTrait;

use super::{
    INVITE_CODE_ALPHABET, INVITE_CODE_LEN, PlayerLoginRequest, PlayerRegisterRequest,
    generate_invite_code, hash_password, login_with_firebase_identity, player_login,
    player_register, register_player_with_code_factory, verify_password,
};

#[test]
fn password_hash_roundtrip() {
    let plain = "super-secret-password";
    let hash = hash_password(plain).expect("hash");
    verify_password(plain, &hash).expect("verify");
}

#[test]
fn invite_code_uses_friendly_charset() {
    let code = generate_invite_code();
    assert_eq!(code.len(), INVITE_CODE_LEN);
    assert!(code.bytes().all(|ch| INVITE_CODE_ALPHABET.contains(&ch)));
}

#[tokio::test]
async fn register_and_login_flow_works() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let state = ctx.app_state();
    let player_id = format!("player_{}", &Uuid::new_v4().simple().to_string()[..8]);
    let pin_code = "1234";

    let (status, response) = player_register(
        State(state.clone()),
        Json(PlayerRegisterRequest {
            player_id: player_id.clone(),
            pin_code: pin_code.to_string(),
            display_name: "Cozy Player".to_string(),
            avatar_type: Some("novice".to_string()),
        }),
    )
    .await?;
    assert_eq!(status, axum::http::StatusCode::CREATED);
    assert_eq!(response.role, crate::jwt::AuthRole::Player);
    assert_eq!(response.guild_role, crate::jwt::GuildRole::Master);
    assert_eq!(response.player_id.as_deref(), Some(player_id.as_str()));

    let login_response = player_login(
        State(state),
        Json(PlayerLoginRequest {
            player_id: player_id.clone(),
            pin_code: pin_code.to_string(),
        }),
    )
    .await?;
    assert_eq!(login_response.role, crate::jwt::AuthRole::Player);
    assert_eq!(login_response.guild_id, response.guild_id);
    assert!(login_response.hunter_id.is_some());
    assert_eq!(
        login_response.player_id.as_deref(),
        Some(player_id.as_str())
    );

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn register_rolls_back_user_when_guild_insert_fails() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let state = ctx.app_state();
    let player_id = format!("rollback_{}", &Uuid::new_v4().simple().to_string()[..8]);
    let long_display_name = "X".repeat(300);

    let err = player_register(
        State(state.clone()),
        Json(PlayerRegisterRequest {
            player_id: player_id.clone(),
            pin_code: "1234".to_string(),
            display_name: long_display_name,
            avatar_type: Some("novice".to_string()),
        }),
    )
    .await
    .expect_err("register should fail when guild insert fails");
    assert!(matches!(err, crate::error::AppError::Database(_)));

    let synthetic_email = format!("player_{player_id}@players.local");
    let maybe_user = user::Entity::find()
        .filter(user::Column::Email.eq(synthetic_email))
        .one(&state.db)
        .await?;
    assert!(
        maybe_user.is_none(),
        "user insert should rollback when guild insert fails"
    );

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn register_retries_when_invite_code_collides() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let state = ctx.app_state();

    let existing_user_id = Uuid::new_v4();
    let existing_user = user::ActiveModel {
        id: Set(existing_user_id),
        email: Set(format!("existing-{}@example.com", Uuid::new_v4().simple())),
        password_hash: Set(hash_password("Passw0rd!")?),
        hunter_tag: Set("ID-EXIST1".to_string()),
        current_role: Set("Guardian".to_string()),
        created_at: Set(Utc::now()),
    }
    .insert(&state.db)
    .await?;

    let existing_hunter_id = Uuid::new_v4();
    guild::ActiveModel {
        id: Set(Uuid::new_v4()),
        name: Set("Existing Guild".to_string()),
        owner_id: Set(existing_user.id),
        invite_code: Set("ABCDEF".to_string()),
    }
    .insert(&state.db)
    .await?;
    hunter::ActiveModel {
        id: Set(existing_hunter_id),
        guild_id: Set(guild::Entity::find()
            .filter(guild::Column::OwnerId.eq(existing_user.id))
            .one(&state.db)
            .await?
            .expect("guild exists")
            .id),
        user_id: Set(Some(existing_user.id)),
        player_id: Set("existing_owner".to_string()),
        name: Set("Existing Owner".to_string()),
        avatar_type: Set("master".to_string()),
        level: Set(1),
        xp: Set(0),
        coins: Set(0),
        pin_code: Set("$argon2id$fake$hash".to_string()),
        guild_role: Set("master".to_string()),
        motto: Set(None),
    }
    .insert(&state.db)
    .await?;

    let mut codes = vec!["ABCDEF".to_string(), "QWERTY".to_string()].into_iter();
    let response = register_player_with_code_factory(
        &state,
        PlayerRegisterRequest {
            player_id: format!("collision_{}", &Uuid::new_v4().simple().to_string()[..8]),
            pin_code: "2468".to_string(),
            display_name: "Retry Player".to_string(),
            avatar_type: Some("novice".to_string()),
        },
        || codes.next().unwrap_or_else(|| "ZXCVBN".to_string()),
    )
    .await?;

    assert_eq!(response.role, crate::jwt::AuthRole::Player);
    let hunter_id = response.hunter_id.expect("hunter_id must exist");

    let inserted_hunter = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .expect("hunter should exist");
    assert!(inserted_hunter.pin_code.starts_with("$argon2"));

    let inserted_guild = guild::Entity::find_by_id(inserted_hunter.guild_id)
        .one(&state.db)
        .await?
        .expect("guild should exist");
    assert_eq!(inserted_guild.invite_code, "QWERTY");

    ctx.cleanup().await?;
    Ok(())
}

#[tokio::test]
async fn firebase_login_creates_owner_hunter_with_avatar_profile() -> Result<(), Box<dyn Error>> {
    let ctx = TestDbContext::create().await?;
    let state = ctx.app_state();
    let email = format!("google_{}@example.com", Uuid::new_v4().simple());

    let response = login_with_firebase_identity(
        &state,
        FirebaseIdentity {
            uid: format!("firebase_uid_{}", Uuid::new_v4().simple()),
            email: email.clone(),
            display_name: Some("Pixel Hero".to_string()),
        },
        Some("Pixel Hero".to_string()),
        Some("hair:ponytail|cloth:plum".to_string()),
    )
    .await?;

    let hunter_id = response
        .hunter_id
        .expect("firebase login should issue hunter");
    let inserted_hunter = hunter::Entity::find_by_id(hunter_id)
        .one(&state.db)
        .await?
        .expect("hunter should exist");
    assert_eq!(inserted_hunter.name, "Pixel Hero");
    assert_eq!(inserted_hunter.avatar_type, "hair:ponytail|cloth:plum");
    assert_eq!(
        response.avatar_type.as_deref(),
        Some("hair:ponytail|cloth:plum")
    );

    let inserted_user = user::Entity::find()
        .filter(user::Column::Email.eq(email))
        .one(&state.db)
        .await?
        .expect("user should exist");
    let inserted_guild = guild::Entity::find()
        .filter(guild::Column::OwnerId.eq(inserted_user.id))
        .one(&state.db)
        .await?
        .expect("guild should exist");
    assert_eq!(inserted_guild.id, response.guild_id);

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
        let base_url = std::env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://chen:chen@127.0.0.1:5433/the_bit_and_bond".to_string());
        let db_name = format!("the_bit_and_bond_it_{}", Uuid::new_v4().simple());
        let admin_url = replace_database_name(&base_url, "postgres")?;
        let test_url = replace_database_name(&base_url, &db_name)?;

        let admin_db = Database::connect(admin_url).await?;
        let create_sql = format!("CREATE DATABASE \"{db_name}\"");
        admin_db
            .execute(Statement::from_string(
                DatabaseBackend::Postgres,
                create_sql,
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

    fn app_state(&self) -> AppState {
        let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
        AppState::new(self.app_db.clone(), jwt)
    }

    async fn cleanup(self) -> Result<(), Box<dyn Error>> {
        self.app_db.close().await?;
        let drop_sql = format!("DROP DATABASE IF EXISTS \"{}\" WITH (FORCE)", self.db_name);
        self.admin_db
            .execute(Statement::from_string(DatabaseBackend::Postgres, drop_sql))
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
