use std::{collections::HashMap, sync::Arc, time::Duration};

use chrono::Utc;
use futures_util::StreamExt;
use redis::{AsyncCommands, aio::ConnectionManager};
use serde::{Deserialize, Serialize};
use tokio::sync::{RwLock, broadcast};
use tracing::warn;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HunterFacing {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HunterPose {
    pub hunter_id: Uuid,
    pub x: f32,
    pub y: f32,
    pub facing: HunterFacing,
    pub moving: bool,
    pub updated_at_ms: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum PresenceEvent {
    Pose { session_id: Uuid, pose: HunterPose },
    ChatNotice { room_id: String, message_id: Uuid },
}

struct SessionPose {
    session_id: Uuid,
    pose: HunterPose,
}

struct GuildPresence {
    tx: broadcast::Sender<PresenceEvent>,
    poses: HashMap<Uuid, SessionPose>,
}

const POSE_STALE_MS: i64 = 12_000;

#[derive(Clone, Default)]
pub struct InMemoryPresenceHub {
    inner: Arc<RwLock<HashMap<Uuid, GuildPresence>>>,
}

impl InMemoryPresenceHub {
    fn new() -> Self {
        Self::default()
    }

    async fn subscribe(
        &self,
        guild_id: Uuid,
    ) -> (Uuid, broadcast::Receiver<PresenceEvent>, Vec<HunterPose>) {
        let mut guard = self.inner.write().await;
        let guild = guard.entry(guild_id).or_insert_with(|| {
            let (tx, _rx) = broadcast::channel(256);
            GuildPresence {
                tx,
                poses: HashMap::new(),
            }
        });
        prune_stale_poses(guild, Utc::now().timestamp_millis());
        let receiver = guild.tx.subscribe();
        let snapshot = guild
            .poses
            .values()
            .map(|entry| entry.pose.clone())
            .collect();
        (Uuid::new_v4(), receiver, snapshot)
    }

    async fn publish_pose(&self, guild_id: Uuid, session_id: Uuid, pose: HunterPose) {
        self.publish_event(guild_id, PresenceEvent::Pose { session_id, pose })
            .await;
    }

    async fn publish_chat_notice(&self, guild_id: Uuid, room_id: String, message_id: Uuid) {
        self.publish_event(
            guild_id,
            PresenceEvent::ChatNotice {
                room_id,
                message_id,
            },
        )
        .await;
    }

    async fn publish_event(&self, guild_id: Uuid, event: PresenceEvent) {
        let mut guard = self.inner.write().await;
        let guild = guard.entry(guild_id).or_insert_with(|| {
            let (tx, _rx) = broadcast::channel(256);
            GuildPresence {
                tx,
                poses: HashMap::new(),
            }
        });
        let now_ms = Utc::now().timestamp_millis();
        prune_stale_poses(guild, now_ms);

        if let PresenceEvent::Pose { session_id, pose } = &event {
            guild.poses.insert(
                pose.hunter_id,
                SessionPose {
                    session_id: *session_id,
                    pose: pose.clone(),
                },
            );
        }
        let _ = guild.tx.send(event);
    }

    async fn remove_session(&self, guild_id: Uuid, session_id: Uuid) {
        let mut guard = self.inner.write().await;
        let Some(guild) = guard.get_mut(&guild_id) else {
            return;
        };
        guild
            .poses
            .retain(|_, entry| entry.session_id != session_id);
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct RedisPresenceEnvelope {
    node_id: Uuid,
    guild_id: Uuid,
    event: RedisPresencePayload,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
enum RedisPresencePayload {
    Pose { session_id: Uuid, pose: HunterPose },
    ChatNotice { room_id: String, message_id: Uuid },
}

#[derive(Clone)]
pub struct RedisPresenceHub {
    node_id: Uuid,
    local: InMemoryPresenceHub,
    publisher: ConnectionManager,
}

impl RedisPresenceHub {
    async fn connect(redis_url: &str) -> Result<Self, redis::RedisError> {
        let client = redis::Client::open(redis_url)?;
        let publisher = ConnectionManager::new(client.clone()).await?;
        let node_id = Uuid::new_v4();
        let local = InMemoryPresenceHub::new();
        tokio::spawn(run_redis_subscriber_loop(client, local.clone(), node_id));
        Ok(Self {
            node_id,
            local,
            publisher,
        })
    }

    async fn subscribe(
        &self,
        guild_id: Uuid,
    ) -> (Uuid, broadcast::Receiver<PresenceEvent>, Vec<HunterPose>) {
        self.local.subscribe(guild_id).await
    }

    async fn publish_pose(&self, guild_id: Uuid, session_id: Uuid, pose: HunterPose) {
        self.local
            .publish_pose(guild_id, session_id, pose.clone())
            .await;

        self.publish_redis_event(guild_id, RedisPresencePayload::Pose { session_id, pose })
            .await;
    }

    async fn publish_chat_notice(&self, guild_id: Uuid, room_id: String, message_id: Uuid) {
        self.local
            .publish_chat_notice(guild_id, room_id.clone(), message_id)
            .await;

        self.publish_redis_event(
            guild_id,
            RedisPresencePayload::ChatNotice {
                room_id,
                message_id,
            },
        )
        .await;
    }

    async fn publish_redis_event(&self, guild_id: Uuid, event: RedisPresencePayload) {
        let payload = match serde_json::to_string(&RedisPresenceEnvelope {
            node_id: self.node_id,
            guild_id,
            event,
        }) {
            Ok(v) => v,
            Err(err) => {
                warn!(error = %err, "failed to encode redis presence event");
                return;
            }
        };
        let channel = redis_channel(guild_id);
        let mut publisher = self.publisher.clone();
        if let Err(err) = publisher.publish::<_, _, i64>(channel, payload).await {
            warn!(error = %err, "failed to publish redis presence event");
        }
    }

    async fn remove_session(&self, guild_id: Uuid, session_id: Uuid) {
        self.local.remove_session(guild_id, session_id).await;
    }
}

async fn run_redis_subscriber_loop(
    client: redis::Client,
    local: InMemoryPresenceHub,
    node_id: Uuid,
) {
    loop {
        let mut pubsub = match client.get_async_pubsub().await {
            Ok(v) => v,
            Err(err) => {
                warn!(error = %err, "failed to connect redis pubsub for presence");
                tokio::time::sleep(Duration::from_millis(750)).await;
                continue;
            }
        };

        if let Err(err) = pubsub.psubscribe("presence:guild:*").await {
            warn!(error = %err, "failed to psubscribe presence channels");
            tokio::time::sleep(Duration::from_millis(750)).await;
            continue;
        }

        let mut stream = pubsub.on_message();
        while let Some(message) = stream.next().await {
            let payload: String = match message.get_payload() {
                Ok(v) => v,
                Err(err) => {
                    warn!(error = %err, "failed to decode redis presence payload");
                    continue;
                }
            };
            let envelope: RedisPresenceEnvelope = match serde_json::from_str(&payload) {
                Ok(v) => v,
                Err(err) => {
                    warn!(error = %err, "failed to parse redis presence envelope");
                    continue;
                }
            };
            if envelope.node_id == node_id {
                continue;
            }
            match envelope.event {
                RedisPresencePayload::Pose { session_id, pose } => {
                    local
                        .publish_pose(envelope.guild_id, session_id, pose)
                        .await;
                }
                RedisPresencePayload::ChatNotice {
                    room_id,
                    message_id,
                } => {
                    local
                        .publish_chat_notice(envelope.guild_id, room_id, message_id)
                        .await;
                }
            }
        }

        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

fn redis_channel(guild_id: Uuid) -> String {
    format!("presence:guild:{guild_id}")
}

#[derive(Clone)]
pub enum PresenceHub {
    InMemory(InMemoryPresenceHub),
    Redis(Box<RedisPresenceHub>),
}

impl Default for PresenceHub {
    fn default() -> Self {
        Self::InMemory(InMemoryPresenceHub::new())
    }
}

impl PresenceHub {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn with_redis(redis_url: &str) -> Result<Self, redis::RedisError> {
        Ok(Self::Redis(Box::new(
            RedisPresenceHub::connect(redis_url).await?,
        )))
    }

    pub async fn subscribe(
        &self,
        guild_id: Uuid,
    ) -> (Uuid, broadcast::Receiver<PresenceEvent>, Vec<HunterPose>) {
        match self {
            Self::InMemory(hub) => hub.subscribe(guild_id).await,
            Self::Redis(hub) => hub.subscribe(guild_id).await,
        }
    }

    pub async fn publish_pose(&self, guild_id: Uuid, session_id: Uuid, pose: HunterPose) {
        match self {
            Self::InMemory(hub) => hub.publish_pose(guild_id, session_id, pose).await,
            Self::Redis(hub) => hub.publish_pose(guild_id, session_id, pose).await,
        }
    }

    pub async fn publish_chat_notice(&self, guild_id: Uuid, room_id: String, message_id: Uuid) {
        match self {
            Self::InMemory(hub) => hub.publish_chat_notice(guild_id, room_id, message_id).await,
            Self::Redis(hub) => hub.publish_chat_notice(guild_id, room_id, message_id).await,
        }
    }

    pub async fn remove_session(&self, guild_id: Uuid, session_id: Uuid) {
        match self {
            Self::InMemory(hub) => hub.remove_session(guild_id, session_id).await,
            Self::Redis(hub) => hub.remove_session(guild_id, session_id).await,
        }
    }
}

fn prune_stale_poses(guild: &mut GuildPresence, now_ms: i64) {
    guild
        .poses
        .retain(|_, entry| now_ms - entry.pose.updated_at_ms <= POSE_STALE_MS);
}
