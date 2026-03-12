use axum::Router;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

use crate::{api, error::AppResult, state::AppState};

const NGROK_SKIP_BROWSER_WARNING_HEADER: &str = "ngrok-skip-browser-warning";

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
            axum::http::header::HeaderName::from_static(NGROK_SKIP_BROWSER_WARNING_HEADER),
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
    use super::{NGROK_SKIP_BROWSER_WARNING_HEADER, build_cors_layer};
    use axum::{
        Router,
        body::Body,
        http::{Method, Request, StatusCode},
        routing::get,
    };
    use tower::ServiceExt;

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

    #[tokio::test]
    async fn cors_preflight_allows_ngrok_skip_browser_warning_header() {
        let cors =
            build_cors_layer("http://localhost:18081", true).expect("cors layer should build");
        let app = Router::new()
            .route("/", get(|| async { StatusCode::OK }))
            .layer(cors);

        let response = app
            .oneshot(
                Request::builder()
                    .method(Method::OPTIONS)
                    .uri("/")
                    .header("origin", "http://localhost:18081")
                    .header("access-control-request-method", "POST")
                    .header(
                        "access-control-request-headers",
                        format!("content-type,{NGROK_SKIP_BROWSER_WARNING_HEADER}"),
                    )
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("preflight request should succeed");

        assert_eq!(response.status(), StatusCode::OK);
        let allow_headers = response
            .headers()
            .get("access-control-allow-headers")
            .expect("cors should return allow headers")
            .to_str()
            .expect("allow headers should be valid text")
            .to_ascii_lowercase();
        assert!(
            allow_headers.contains(NGROK_SKIP_BROWSER_WARNING_HEADER),
            "expected allow headers to include {NGROK_SKIP_BROWSER_WARNING_HEADER}, got {allow_headers}"
        );
    }
}
