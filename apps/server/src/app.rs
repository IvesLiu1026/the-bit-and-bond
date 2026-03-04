use axum::Router;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

use crate::{api, error::AppResult, state::AppState};

pub fn build_router(state: AppState, allowed_origin: &str) -> AppResult<Router> {
    let cors = build_cors_layer(allowed_origin)?;

    Ok(Router::new()
        .merge(api::router(state))
        .layer(TraceLayer::new_for_http())
        .layer(cors))
}

fn build_cors_layer(allowed_origin: &str) -> AppResult<CorsLayer> {
    let cors = CorsLayer::new()
        .allow_methods([
            axum::http::Method::GET,
            axum::http::Method::POST,
            axum::http::Method::PATCH,
            axum::http::Method::OPTIONS,
        ])
        .allow_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::AUTHORIZATION,
        ]);

    if allowed_origin.trim() == "*" {
        return Ok(cors.allow_origin(Any));
    }

    let origins: Result<Vec<axum::http::HeaderValue>, _> = allowed_origin
        .split(',')
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(str::parse)
        .collect();

    let origins =
        origins.map_err(|_| crate::error::AppError::BadRequest("invalid ALLOWED_ORIGIN".into()))?;
    if origins.is_empty() {
        return Err(crate::error::AppError::BadRequest(
            "ALLOWED_ORIGIN must not be empty".into(),
        ));
    }

    Ok(cors.allow_origin(origins))
}
