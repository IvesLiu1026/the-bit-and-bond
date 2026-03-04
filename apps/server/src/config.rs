use std::env;

pub struct Config {
    pub bind_addr: String,
    pub database_url: String,
    pub allowed_origin: String,
    pub auto_migrate: bool,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            bind_addr: env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:18080".to_string()),
            database_url: env::var("DATABASE_URL").unwrap_or_else(|_| {
                "postgres://chen:chen@127.0.0.1:5433/chen_leveling".to_string()
            }),
            allowed_origin: env::var("ALLOWED_ORIGIN").unwrap_or_else(|_| "*".to_string()),
            auto_migrate: parse_auto_migrate(env::var("AUTO_MIGRATE").ok()),
        }
    }
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
