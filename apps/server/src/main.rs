mod api;
mod app;
mod auth;
mod config;
mod error;
mod extractors;
mod jwt;
mod presence;
mod state;

use std::net::SocketAddr;

use crate::{app::build_router, config::Config, state::AppState};
use migration::MigratorTrait;
use sea_orm::Database;
use tracing::info;

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

    let state = AppState::new(db, jwt);
    let app = build_router(state, &cfg.allowed_origin)?;

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
