use std::collections::{HashMap, HashSet};

use axum::{
    Json,
    extract::{Query, State},
    http::StatusCode,
};
use chrono::{TimeZone, Utc};
use entity::{chat_message, hunter};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DbErr, EntityTrait, QueryFilter, QueryOrder,
    QuerySelect,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::AuthClaims,
    state::AppState,
};

const DEFAULT_HISTORY_LIMIT: u64 = 50;
const MAX_HISTORY_LIMIT: u64 = 200;
const MAX_CHAT_CONTENT_LEN: usize = 480;

#[derive(Debug, Deserialize)]
pub struct PersistChatMessageRequest {
    pub room_id: Option<String>,
    pub client_message_id: Option<Uuid>,
    pub content: String,
    pub sent_at_ms: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct ChatHistoryQuery {
    pub room_id: Option<String>,
    pub limit: Option<u64>,
    pub before_ms: Option<i64>,
}

#[derive(Debug, Serialize, Clone)]
pub struct ChatMessageResponse {
    pub id: Uuid,
    pub guild_id: Uuid,
    pub room_id: String,
    pub sender_hunter_id: Uuid,
    pub sender_name: String,
    pub client_message_id: Uuid,
    pub content: String,
    pub sent_at: chrono::DateTime<chrono::Utc>,
    pub sent_at_ms: i64,
}

pub async fn persist_chat_message(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Json(payload): Json<PersistChatMessageRequest>,
) -> AppResult<(StatusCode, Json<ChatMessageResponse>)> {
    let room_id = normalize_room_id(payload.room_id.as_deref(), claims.guild_id)?;
    let content = payload.content.trim();
    if content.is_empty() {
        return Err(AppError::BadRequest("content must not be empty".into()));
    }
    if content.chars().count() > MAX_CHAT_CONTENT_LEN {
        return Err(AppError::BadRequest(format!(
            "content too long, max {} characters",
            MAX_CHAT_CONTENT_LEN
        )));
    }

    let client_message_id = payload.client_message_id.unwrap_or_else(Uuid::new_v4);
    let sent_at = payload
        .sent_at_ms
        .and_then(|ms| Utc.timestamp_millis_opt(ms).single())
        .unwrap_or_else(Utc::now);

    let model = match (chat_message::ActiveModel {
        id: Set(Uuid::new_v4()),
        guild_id: Set(claims.guild_id),
        sender_hunter_id: Set(claims.sub),
        room_id: Set(room_id.clone()),
        client_message_id: Set(client_message_id),
        content: Set(content.to_string()),
        sent_at: Set(sent_at.into()),
    }
    .insert(&state.db)
    .await)
    {
        Ok(model) => model,
        Err(err) => {
            if !is_chat_dedupe_violation(&err) {
                return Err(err.into());
            }
            chat_message::Entity::find()
                .filter(chat_message::Column::GuildId.eq(claims.guild_id))
                .filter(chat_message::Column::RoomId.eq(room_id.clone()))
                .filter(chat_message::Column::ClientMessageId.eq(client_message_id))
                .one(&state.db)
                .await?
                .ok_or_else(|| {
                    AppError::Conflict(
                        "message dedupe conflict detected but existing row not found".into(),
                    )
                })?
        }
    };

    let sender = hunter::Entity::find_by_id(model.sender_hunter_id)
        .filter(hunter::Column::GuildId.eq(model.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("sender hunter no longer exists".into()))?;

    let response = map_chat_message(&model, &sender.name);
    Ok((StatusCode::OK, Json(response)))
}

pub async fn list_chat_history(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Query(query): Query<ChatHistoryQuery>,
) -> AppResult<Json<Vec<ChatMessageResponse>>> {
    let room_id = normalize_room_id(query.room_id.as_deref(), claims.guild_id)?;
    let limit = query
        .limit
        .unwrap_or(DEFAULT_HISTORY_LIMIT)
        .min(MAX_HISTORY_LIMIT);

    let mut finder = chat_message::Entity::find()
        .filter(chat_message::Column::GuildId.eq(claims.guild_id))
        .filter(chat_message::Column::RoomId.eq(room_id.clone()));

    if let Some(before_ms) = query.before_ms {
        let before = Utc
            .timestamp_millis_opt(before_ms)
            .single()
            .ok_or_else(|| AppError::BadRequest("invalid before_ms".into()))?;
        finder = finder.filter(chat_message::Column::SentAt.lt(before));
    }

    let mut rows = finder
        .order_by_desc(chat_message::Column::SentAt)
        .order_by_desc(chat_message::Column::Id)
        .limit(limit)
        .all(&state.db)
        .await?;

    let sender_ids: HashSet<Uuid> = rows.iter().map(|row| row.sender_hunter_id).collect();
    let senders = hunter::Entity::find()
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .filter(hunter::Column::Id.is_in(sender_ids))
        .all(&state.db)
        .await?;
    let sender_name_map: HashMap<Uuid, String> = senders
        .into_iter()
        .map(|model| (model.id, model.name))
        .collect();

    rows.reverse();
    let messages = rows
        .iter()
        .map(|row| {
            let sender_name = sender_name_map
                .get(&row.sender_hunter_id)
                .cloned()
                .unwrap_or_else(|| "Unknown".to_string());
            map_chat_message(row, &sender_name)
        })
        .collect();

    Ok(Json(messages))
}

pub fn default_guild_chat_room(guild_id: Uuid) -> String {
    format!("guild_{guild_id}:campfire")
}

fn normalize_room_id(raw: Option<&str>, guild_id: Uuid) -> AppResult<String> {
    let default_room = default_guild_chat_room(guild_id);
    let room = raw.map(str::trim).unwrap_or_default();
    if room.is_empty() {
        return Ok(default_room);
    }
    if room.chars().count() > 96 {
        return Err(AppError::BadRequest("room_id too long".into()));
    }

    let guild_prefix = format!("guild_{guild_id}");
    if !room.starts_with(&guild_prefix) {
        return Err(AppError::Forbidden(
            "room_id is outside current guild scope".into(),
        ));
    }
    Ok(room.to_string())
}

fn map_chat_message(model: &chat_message::Model, sender_name: &str) -> ChatMessageResponse {
    let sent_at = model.sent_at.with_timezone(&Utc);
    ChatMessageResponse {
        id: model.id,
        guild_id: model.guild_id,
        room_id: model.room_id.clone(),
        sender_hunter_id: model.sender_hunter_id,
        sender_name: sender_name.to_string(),
        client_message_id: model.client_message_id,
        content: model.content.clone(),
        sent_at,
        sent_at_ms: sent_at.timestamp_millis(),
    }
}

fn is_chat_dedupe_violation(err: &DbErr) -> bool {
    match err.sql_err() {
        Some(sea_orm::SqlErr::UniqueConstraintViolation(message)) => {
            message.contains("idx_chat_messages_room_client_unique")
                || message.contains("chat_messages_guild_id_room_id_client_message_id")
                || message.contains("client_message_id")
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;

    use axum::{Json, extract::State};
    use chrono::Utc;
    use entity::{guild, hunter, user};
    use migration::MigratorTrait;
    use sea_orm::{
        ActiveModelTrait, ActiveValue::Set, ConnectionTrait, Database, DatabaseBackend, Statement,
    };
    use uuid::Uuid;

    use crate::{
        extractors::AuthClaims,
        jwt::{AuthRole, Claims, GuildRole, JwtService},
        state::AppState,
    };

    use super::{
        ChatHistoryQuery, PersistChatMessageRequest, default_guild_chat_room, list_chat_history,
        normalize_room_id, persist_chat_message,
    };

    #[test]
    fn room_normalization_is_guild_scoped() {
        let guild = Uuid::new_v4();
        let room = normalize_room_id(None, guild).expect("default room");
        assert_eq!(room, default_guild_chat_room(guild));

        let forbidden = normalize_room_id(Some("guild_other:campfire"), guild)
            .expect_err("cross guild room should fail");
        assert!(matches!(forbidden, crate::error::AppError::Forbidden(_)));
    }

    #[tokio::test]
    async fn persist_and_list_history_happy_path() -> Result<(), Box<dyn Error>> {
        let ctx = TestDbContext::create().await?;
        let (state, claims) = ctx.seed_guild_and_hunter("chat").await?;
        let room_id = default_guild_chat_room(claims.0.guild_id);

        let (_, saved) = persist_chat_message(
            claims.clone(),
            State(state.clone()),
            Json(PersistChatMessageRequest {
                room_id: Some(room_id.clone()),
                client_message_id: Some(Uuid::new_v4()),
                content: "Hello guild".to_string(),
                sent_at_ms: Some(Utc::now().timestamp_millis()),
            }),
        )
        .await?;
        assert_eq!(saved.room_id, room_id);
        assert_eq!(saved.sender_hunter_id, claims.0.sub);

        let history = list_chat_history(
            claims,
            State(state),
            axum::extract::Query(ChatHistoryQuery {
                room_id: Some(room_id),
                limit: Some(20),
                before_ms: None,
            }),
        )
        .await?;
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].content, "Hello guild");

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
            let db_name = format!("the_bit_and_bond_it_chat_{}", Uuid::new_v4().simple());
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

        async fn seed_guild_and_hunter(
            &self,
            suffix: &str,
        ) -> Result<(AppState, AuthClaims), Box<dyn Error>> {
            let user_id = Uuid::new_v4();
            let guild_id = Uuid::new_v4();
            let hunter_id = Uuid::new_v4();

            user::ActiveModel {
                id: Set(user_id),
                email: Set(format!("chat-{suffix}@example.com")),
                password_hash: Set("$argon2id$fake$hash".to_string()),
                hunter_tag: Set(format!("ID-CHAT-{suffix}")),
                current_role: Set("Explorer".to_string()),
                created_at: Set(Utc::now()),
            }
            .insert(&self.app_db)
            .await?;

            guild::ActiveModel {
                id: Set(guild_id),
                name: Set(format!("guild-{suffix}")),
                owner_id: Set(user_id),
                invite_code: Set("CHAT01".to_string()),
            }
            .insert(&self.app_db)
            .await?;

            hunter::ActiveModel {
                id: Set(hunter_id),
                guild_id: Set(guild_id),
                user_id: Set(Some(user_id)),
                player_id: Set(format!("player_{suffix}")),
                name: Set(format!("Hunter-{suffix}")),
                avatar_type: Set("novice".to_string()),
                level: Set(1),
                xp: Set(0),
                coins: Set(0),
                pin_code: Set("$argon2id$seed".to_string()),
                guild_role: Set("master".to_string()),
                motto: Set(None),
            }
            .insert(&self.app_db)
            .await?;

            let jwt = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
            let state = AppState::new(self.app_db.clone(), jwt);
            let claims = AuthClaims(Claims {
                sub: hunter_id,
                role: AuthRole::Player,
                guild_role: GuildRole::Master,
                guild_id,
                hunter_id: Some(hunter_id),
                iat: 0,
                exp: 9_999_999_999,
            });

            Ok((state, claims))
        }

        async fn cleanup(&self) -> Result<(), Box<dyn Error>> {
            self.admin_db
                .execute(Statement::from_string(
                    DatabaseBackend::Postgres,
                    format!(
                        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{}' AND pid <> pg_backend_pid()",
                        self.db_name
                    ),
                ))
                .await?;

            self.admin_db
                .execute(Statement::from_string(
                    DatabaseBackend::Postgres,
                    format!("DROP DATABASE IF EXISTS \"{}\"", self.db_name),
                ))
                .await?;
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
