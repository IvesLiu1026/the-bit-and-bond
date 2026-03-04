use std::{collections::HashMap, sync::Arc};

use serde::{Deserialize, Serialize};
use tokio::sync::{RwLock, broadcast};
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

#[derive(Debug, Clone)]
pub struct PresenceEvent {
    pub session_id: Uuid,
    pub pose: HunterPose,
}

struct SessionPose {
    session_id: Uuid,
    pose: HunterPose,
}

struct GuildPresence {
    tx: broadcast::Sender<PresenceEvent>,
    poses: HashMap<Uuid, SessionPose>,
}

#[derive(Clone, Default)]
pub struct PresenceHub {
    inner: Arc<RwLock<HashMap<Uuid, GuildPresence>>>,
}

impl PresenceHub {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn subscribe(
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
        let receiver = guild.tx.subscribe();
        let snapshot = guild
            .poses
            .values()
            .map(|entry| entry.pose.clone())
            .collect();
        (Uuid::new_v4(), receiver, snapshot)
    }

    pub async fn publish_pose(&self, guild_id: Uuid, event: PresenceEvent) {
        let mut guard = self.inner.write().await;
        let guild = guard.entry(guild_id).or_insert_with(|| {
            let (tx, _rx) = broadcast::channel(256);
            GuildPresence {
                tx,
                poses: HashMap::new(),
            }
        });
        guild.poses.insert(
            event.pose.hunter_id,
            SessionPose {
                session_id: event.session_id,
                pose: event.pose.clone(),
            },
        );
        let _ = guild.tx.send(event);
    }

    pub async fn remove_session(&self, guild_id: Uuid, session_id: Uuid) {
        let mut guard = self.inner.write().await;
        let Some(guild) = guard.get_mut(&guild_id) else {
            return;
        };
        guild
            .poses
            .retain(|_, entry| entry.session_id != session_id);
    }
}
