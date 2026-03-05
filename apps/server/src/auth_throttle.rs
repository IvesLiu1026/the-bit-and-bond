use std::{collections::HashMap, sync::Arc};

use chrono::Utc;
use tokio::sync::Mutex;

#[derive(Clone)]
pub struct AuthThrottle {
    inner: Arc<Mutex<HashMap<String, AttemptState>>>,
    max_failures_before_lock: u32,
    max_lock_seconds: i64,
}

#[derive(Debug, Clone)]
struct AttemptState {
    failures: u32,
    blocked_until_ms: i64,
    last_seen_ms: i64,
}

impl AuthThrottle {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(HashMap::new())),
            max_failures_before_lock: 5,
            max_lock_seconds: 10 * 60,
        }
    }

    pub async fn blocked_seconds(&self, key: &str) -> i64 {
        let now = Utc::now().timestamp_millis();
        let mut map = self.inner.lock().await;
        cleanup_expired(now, &mut map);

        map.get(key)
            .map(|state| ((state.blocked_until_ms - now) / 1000).max(0))
            .unwrap_or(0)
    }

    pub async fn record_success(&self, key: &str) {
        let mut map = self.inner.lock().await;
        map.remove(key);
    }

    pub async fn record_failure(&self, key: &str) {
        let now = Utc::now().timestamp_millis();
        let mut map = self.inner.lock().await;
        cleanup_expired(now, &mut map);

        let state = map.entry(key.to_string()).or_insert(AttemptState {
            failures: 0,
            blocked_until_ms: 0,
            last_seen_ms: now,
        });
        state.failures = state.failures.saturating_add(1);
        state.last_seen_ms = now;

        if state.failures >= self.max_failures_before_lock {
            let extra_failures = state
                .failures
                .saturating_sub(self.max_failures_before_lock)
                .saturating_add(1);
            let lock_seconds = (30_i64 * i64::from(extra_failures)).min(self.max_lock_seconds);
            state.blocked_until_ms = now + lock_seconds * 1000;
        }
    }
}

fn cleanup_expired(now_ms: i64, map: &mut HashMap<String, AttemptState>) {
    const FORGET_AFTER_MS: i64 = 30 * 60 * 1000;
    map.retain(|_, state| {
        let recently_seen = now_ms - state.last_seen_ms <= FORGET_AFTER_MS;
        let still_blocked = state.blocked_until_ms > now_ms;
        recently_seen || still_blocked
    });
}

#[cfg(test)]
mod tests {
    use super::AuthThrottle;

    #[tokio::test]
    async fn locks_after_repeated_failures_and_clears_on_success() {
        let throttle = AuthThrottle::new();
        let key = "acct:test";

        for _ in 0..5 {
            throttle.record_failure(key).await;
        }
        assert!(throttle.blocked_seconds(key).await > 0);

        throttle.record_success(key).await;
        assert_eq!(throttle.blocked_seconds(key).await, 0);
    }
}
