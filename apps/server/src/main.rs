mod api;
mod app;
mod auth;
mod auth_throttle;
mod config;
mod error;
mod extractors;
mod jwt;
mod presence;
mod realtime_ticket;
mod security;
mod state;

use std::net::SocketAddr;

use crate::{
    app::build_router,
    config::Config,
    presence::PresenceHub,
    state::{AppState, LiveKitConfig},
};
use migration::MigratorTrait;
use sea_orm::Database;
use tracing::{info, warn};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    init_tracing();

    let cfg = Config::from_env();
    let db = Database::connect(&cfg.database_url).await?;
    let jwt = jwt::JwtService::from_env()
        .map_err(|err| -> Box<dyn std::error::Error> { Box::new(err) })?;

    if cfg.auto_migrate {
        migration::Migrator::up(&db, None).await?;
        info!("database migration completed");
    }

    let livekit = resolve_livekit_config(&cfg);
    let state = match cfg.redis_url.as_deref() {
        Some(redis_url) => match PresenceHub::with_redis(redis_url).await {
            Ok(hub) => {
                info!(redis_url, "realtime presence uses redis pub/sub");
                AppState::with_presence_and_livekit(db, jwt, hub, livekit.clone())
            }
            Err(err) => {
                warn!(error = %err, "failed to initialize redis presence, fallback to in-memory");
                AppState::with_presence_and_livekit(db, jwt, PresenceHub::new(), livekit.clone())
            }
        },
        None => AppState::with_presence_and_livekit(db, jwt, PresenceHub::new(), livekit),
    };
    let app = build_router(state, &cfg.allowed_origin, cfg.allow_wildcard_origin())?;

    let addr: SocketAddr = cfg.bind_addr.parse()?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    info!(%addr, "chen-leveling server listening");

    axum::serve(listener, app).await?;
    Ok(())
}

fn init_tracing() {
    let env = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| "chen_leveling_server=debug,tower_http=info".into());

    tracing_subscriber::fmt().with_env_filter(env).init();
}

fn resolve_livekit_config(cfg: &Config) -> Option<LiveKitConfig> {
    match (
        cfg.livekit_url.as_ref(),
        cfg.livekit_api_key.as_ref(),
        cfg.livekit_api_secret.as_ref(),
    ) {
        (Some(url), Some(api_key), Some(api_secret)) => Some(LiveKitConfig {
            url: url.clone(),
            api_key: api_key.clone(),
            api_secret: api_secret.clone(),
            token_ttl_seconds: cfg.livekit_token_ttl_seconds,
            chat_topic: cfg.livekit_chat_topic.clone(),
        }),
        (None, None, None) => None,
        _ => {
            warn!("partial LiveKit env detected, voice token endpoint will stay disabled");
            None
        }
    }
}
