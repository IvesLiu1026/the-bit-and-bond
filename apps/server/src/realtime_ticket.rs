use std::{collections::HashMap, sync::Arc};

use chrono::{Duration, Utc};
use tokio::sync::Mutex;
use uuid::Uuid;

use crate::jwt::Claims;

#[derive(Clone)]
pub struct RealtimeTicketStore {
    inner: Arc<Mutex<HashMap<String, TicketEntry>>>,
    ttl_seconds: i64,
}

#[derive(Clone)]
struct TicketEntry {
    claims: Claims,
    expires_at_ms: i64,
}

#[derive(Debug, Clone)]
pub struct IssuedRealtimeTicket {
    pub ticket: String,
    pub expires_in: i64,
}

impl RealtimeTicketStore {
    pub fn new(ttl_seconds: i64) -> Self {
        let normalized_ttl = ttl_seconds.clamp(10, 120);
        Self {
            inner: Arc::new(Mutex::new(HashMap::new())),
            ttl_seconds: normalized_ttl,
        }
    }

    pub async fn issue(&self, claims: &Claims) -> IssuedRealtimeTicket {
        let now = Utc::now().timestamp_millis();
        let expires_at_ms = now + (self.ttl_seconds * 1000);
        let ticket = format!("rt_{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple());
        let entry = TicketEntry {
            claims: claims.clone(),
            expires_at_ms,
        };

        let mut map = self.inner.lock().await;
        cleanup_expired(now, &mut map);
        map.insert(ticket.clone(), entry);

        IssuedRealtimeTicket {
            ticket,
            expires_in: self.ttl_seconds,
        }
    }

    pub async fn consume(&self, ticket: &str) -> Option<Claims> {
        if ticket.trim().is_empty() {
            return None;
        }
        let now = Utc::now().timestamp_millis();
        let mut map = self.inner.lock().await;
        cleanup_expired(now, &mut map);
        let entry = map.remove(ticket)?;
        if entry.expires_at_ms < now {
            return None;
        }

        if entry.claims.exp <= (Utc::now() - Duration::seconds(1)).timestamp() {
            return None;
        }
        Some(entry.claims)
    }
}

fn cleanup_expired(now_ms: i64, map: &mut HashMap<String, TicketEntry>) {
    map.retain(|_, entry| entry.expires_at_ms >= now_ms);
}

#[cfg(test)]
mod tests {
    use uuid::Uuid;

    use crate::jwt::{AuthRole, Claims, GuildRole};

    use super::RealtimeTicketStore;

    #[tokio::test]
    async fn ticket_is_one_time_use() {
        let store = RealtimeTicketStore::new(30);
        let claims = Claims {
            sub: Uuid::new_v4(),
            role: AuthRole::Player,
            guild_role: GuildRole::Member,
            guild_id: Uuid::new_v4(),
            hunter_id: Some(Uuid::new_v4()),
            iat: 0,
            exp: 9_999_999_999,
        };

        let issued = store.issue(&claims).await;
        let consumed_first = store.consume(&issued.ticket).await;
        assert!(consumed_first.is_some());
        let consumed_second = store.consume(&issued.ticket).await;
        assert!(consumed_second.is_none());
    }
}
