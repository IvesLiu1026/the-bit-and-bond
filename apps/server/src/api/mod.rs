mod health;
mod hunters;
mod quests;
mod realtime;

use axum::Router;

use crate::{auth, state::AppState};

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", axum::routing::get(health::health))
        .route("/api/v1/health", axum::routing::get(health::health))
        .route(
            "/api/v1/auth/master/register",
            axum::routing::post(auth::guild_master_register),
        )
        .route(
            "/api/v1/auth/master/login",
            axum::routing::post(auth::guild_master_login),
        )
        .route(
            "/api/v1/auth/hunter/login",
            axum::routing::post(auth::hunter_login),
        )
        .route("/api/v1/auth/me", axum::routing::get(auth::me))
        .route(
            "/api/v1/auth/me/master",
            axum::routing::get(auth::guild_master_me),
        )
        .route(
            "/api/v1/auth/me/hunter",
            axum::routing::get(auth::hunter_me),
        )
        .route(
            "/api/v1/hunters",
            axum::routing::post(hunters::create_hunter).get(hunters::list_hunters),
        )
        .route(
            "/api/v1/hunters/roster",
            axum::routing::get(hunters::list_guild_hunters),
        )
        .route("/api/v1/hunters/me", axum::routing::get(hunters::hunter_me))
        .route(
            "/api/v1/hunters/{hunter_id}/pin",
            axum::routing::patch(hunters::reset_hunter_pin),
        )
        .route(
            "/api/v1/quests",
            axum::routing::post(quests::create_quest).get(quests::list_quests),
        )
        .route(
            "/api/v1/quests/{quest_id}/submit",
            axum::routing::post(quests::submit_quest),
        )
        .route(
            "/api/v1/quests/{quest_id}/review",
            axum::routing::post(quests::review_quest),
        )
        .route(
            "/api/v1/realtime/ws",
            axum::routing::get(realtime::ws_upgrade),
        )
        .with_state(state)
}
