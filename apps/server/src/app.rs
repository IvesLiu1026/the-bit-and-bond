use axum::Router;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

use crate::{api, error::AppResult, state::AppState};

pub fn build_router(
    state: AppState,
    allowed_origin: &str,
    allow_wildcard_origin: bool,
) -> AppResult<Router> {
    let cors = build_cors_layer(allowed_origin, allow_wildcard_origin)?;

    Ok(Router::new()
        .merge(api::router(state))
        .layer(TraceLayer::new_for_http())
        .layer(cors))
}

fn build_cors_layer(allowed_origin: &str, allow_wildcard_origin: bool) -> AppResult<CorsLayer> {
    let cors = CorsLayer::new()
        .allow_methods([
            axum::http::Method::GET,
            axum::http::Method::POST,
            axum::http::Method::PATCH,
            axum::http::Method::PUT,
            axum::http::Method::DELETE,
            axum::http::Method::OPTIONS,
        ])
        .allow_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::AUTHORIZATION,
        ]);

    if allowed_origin.trim() == "*" {
        if !allow_wildcard_origin {
            return Err(crate::error::AppError::BadRequest(
                "ALLOWED_ORIGIN=\"*\" is forbidden in production; set explicit origins".into(),
            ));
        }
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

#[cfg(test)]
mod tests {
    use super::build_cors_layer;

    #[test]
    fn wildcard_origin_requires_explicit_opt_in() {
        let err = build_cors_layer("*", false).expect_err("wildcard should be rejected");
        assert!(matches!(err, crate::error::AppError::BadRequest(_)));
    }

    #[test]
    fn wildcard_origin_allowed_when_opted_in() {
        let _ = build_cors_layer("*", true)
            .expect("wildcard is allowed in development or with override");
    }
}
