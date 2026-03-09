use std::env;

pub struct Config {
    pub app_env: String,
    pub bind_addr: String,
    pub database_url: String,
    pub allowed_origin: String,
    pub allow_any_origin: bool,
    pub redis_url: Option<String>,
    pub auto_migrate: bool,
    pub livekit_url: Option<String>,
    pub livekit_api_key: Option<String>,
    pub livekit_api_secret: Option<String>,
    pub livekit_token_ttl_seconds: i64,
    pub livekit_chat_topic: String,
    pub firebase_project_id: Option<String>,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            app_env: env::var("APP_ENV")
                .ok()
                .map(|v| v.trim().to_ascii_lowercase())
                .filter(|v| !v.is_empty())
                .unwrap_or_else(|| "development".to_string()),
            bind_addr: env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:18080".to_string()),
            database_url: env::var("DATABASE_URL").unwrap_or_else(|_| {
                "postgres://chen:chen@127.0.0.1:5433/the_bit_and_bond".to_string()
            }),
            allowed_origin: env::var("ALLOWED_ORIGIN").unwrap_or_else(|_| "*".to_string()),
            allow_any_origin: env::var("ALLOW_ANY_ORIGIN")
                .ok()
                .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                .unwrap_or(false),
            redis_url: env::var("REDIS_URL")
                .ok()
                .map(|v| v.trim().to_string())
                .filter(|v| !v.is_empty()),
            auto_migrate: parse_auto_migrate(env::var("AUTO_MIGRATE").ok()),
            livekit_url: optional_trimmed("LIVEKIT_URL"),
            livekit_api_key: optional_trimmed("LIVEKIT_API_KEY"),
            livekit_api_secret: optional_trimmed("LIVEKIT_API_SECRET"),
            livekit_token_ttl_seconds: env::var("LIVEKIT_TOKEN_TTL_SECONDS")
                .ok()
                .and_then(|v| v.parse::<i64>().ok())
                .unwrap_or(2 * 60 * 60),
            livekit_chat_topic: env::var("LIVEKIT_CHAT_TOPIC")
                .ok()
                .map(|v| v.trim().to_string())
                .filter(|v| !v.is_empty())
                .unwrap_or_else(|| "guild.chat".to_string()),
            firebase_project_id: optional_trimmed("FIREBASE_PROJECT_ID"),
        }
    }

    pub fn allow_wildcard_origin(&self) -> bool {
        if self.allow_any_origin {
            return true;
        }
        self.app_env != "production"
    }
}

fn optional_trimmed(key: &str) -> Option<String> {
    env::var(key)
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

fn parse_auto_migrate(raw: Option<String>) -> bool {
    raw.map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(true)
}

#[cfg(test)]
mod tests {
    use super::parse_auto_migrate;

    #[test]
    fn auto_migrate_defaults_to_true() {
        assert!(parse_auto_migrate(None));
    }

    #[test]
    fn auto_migrate_accepts_true_values() {
        assert!(parse_auto_migrate(Some("1".to_string())));
        assert!(parse_auto_migrate(Some("true".to_string())));
        assert!(parse_auto_migrate(Some("TRUE".to_string())));
    }

    #[test]
    fn auto_migrate_rejects_non_true_values() {
        assert!(!parse_auto_migrate(Some("0".to_string())));
        assert!(!parse_auto_migrate(Some("false".to_string())));
        assert!(!parse_auto_migrate(Some("yes".to_string())));
    }
}
