use axum::{Json, extract::State, http::StatusCode};
use chrono::{DateTime, Utc};
use entity::telemetry_event;
use sea_orm::{ActiveModelTrait, ActiveValue::Set};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::HunterClaims,
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct TelemetryIngestRequest {
    pub events: Vec<TelemetryEventInput>,
}

#[derive(Debug, Deserialize)]
pub struct TelemetryEventInput {
    pub event_name: String,
    pub status: Option<String>,
    pub source: Option<String>,
    pub platform: Option<String>,
    pub locale: Option<String>,
    pub app_version: Option<String>,
    pub session_id: Option<String>,
    pub occurred_at_ms: Option<i64>,
    pub properties: Option<Value>,
}

#[derive(Debug, Serialize)]
pub struct TelemetryIngestResponse {
    pub accepted: usize,
}

pub async fn ingest_public_events(
    State(state): State<AppState>,
    Json(payload): Json<TelemetryIngestRequest>,
) -> AppResult<(StatusCode, Json<TelemetryIngestResponse>)> {
    let accepted = insert_events(&state, payload.events, None, None).await?;
    Ok((
        StatusCode::ACCEPTED,
        Json(TelemetryIngestResponse { accepted }),
    ))
}

pub async fn ingest_hunter_events(
    HunterClaims(claims): HunterClaims,
    State(state): State<AppState>,
    Json(payload): Json<TelemetryIngestRequest>,
) -> AppResult<(StatusCode, Json<TelemetryIngestResponse>)> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("hunter token missing hunter_id".into()))?;
    let accepted = insert_events(
        &state,
        payload.events,
        Some(claims.guild_id),
        Some(hunter_id),
    )
    .await?;
    Ok((
        StatusCode::ACCEPTED,
        Json(TelemetryIngestResponse { accepted }),
    ))
}

async fn insert_events(
    state: &AppState,
    events: Vec<TelemetryEventInput>,
    guild_id: Option<Uuid>,
    hunter_id: Option<Uuid>,
) -> AppResult<usize> {
    if events.is_empty() {
        return Err(AppError::BadRequest(
            "events payload cannot be empty".into(),
        ));
    }

    let mut accepted = 0usize;
    for event in events.into_iter().take(100) {
        let event_name = normalize_event_name(&event.event_name)?;
        let status = normalize_optional(event.status, 24);
        let source = normalize_optional(event.source, 24).unwrap_or_else(|| "client".to_string());
        let platform = normalize_optional(event.platform, 24);
        let locale = normalize_optional(event.locale, 16);
        let app_version = normalize_optional(event.app_version, 32);
        let session_id = normalize_optional(event.session_id, 64);
        let properties_json = normalize_properties(event.properties)?;
        let occurred_at = normalize_occurred_at(event.occurred_at_ms);

        telemetry_event::ActiveModel {
            id: Set(Uuid::new_v4()),
            guild_id: Set(guild_id),
            hunter_id: Set(hunter_id),
            event_name: Set(event_name),
            status: Set(status),
            source: Set(source),
            platform: Set(platform),
            locale: Set(locale),
            app_version: Set(app_version),
            session_id: Set(session_id),
            properties_json: Set(properties_json),
            occurred_at: Set(occurred_at.into()),
            created_at: Set(Utc::now().into()),
        }
        .insert(&state.db)
        .await?;
        accepted += 1;
    }

    Ok(accepted)
}

fn normalize_event_name(raw: &str) -> AppResult<String> {
    let normalized = raw.trim().to_lowercase();
    if normalized.len() < 2 || normalized.len() > 80 {
        return Err(AppError::BadRequest(
            "event_name must be between 2 and 80 chars".into(),
        ));
    }
    if !normalized
        .chars()
        .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || matches!(ch, '.' | '_' | '-'))
    {
        return Err(AppError::BadRequest(
            "event_name only supports [a-z0-9._-]".into(),
        ));
    }
    Ok(normalized)
}

fn normalize_optional(value: Option<String>, max_len: usize) -> Option<String> {
    value.and_then(|raw| {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return None;
        }
        let clipped = if trimmed.len() > max_len {
            &trimmed[..max_len]
        } else {
            trimmed
        };
        Some(clipped.to_string())
    })
}

fn normalize_properties(value: Option<Value>) -> AppResult<String> {
    match value {
        None => Ok("{}".to_string()),
        Some(raw) => serde_json::to_string(&raw)
            .map_err(|_| AppError::BadRequest("invalid properties payload".into())),
    }
}

fn normalize_occurred_at(occurred_at_ms: Option<i64>) -> DateTime<Utc> {
    if let Some(ms) = occurred_at_ms
        && let Some(ts) = DateTime::<Utc>::from_timestamp_millis(ms)
    {
        return ts;
    }
    Utc::now()
}

#[cfg(test)]
mod tests {
    use super::normalize_event_name;

    #[test]
    fn normalize_event_name_accepts_expected_chars() {
        let ok = normalize_event_name("dm.image_send.success").expect("should normalize");
        assert_eq!(ok, "dm.image_send.success");
    }

    #[test]
    fn normalize_event_name_rejects_invalid_chars() {
        let err = normalize_event_name("dm image").expect_err("should reject whitespace");
        assert!(format!("{err}").contains("event_name"));
    }
}
