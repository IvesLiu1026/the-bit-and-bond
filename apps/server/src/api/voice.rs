use axum::{Json, extract::State};
use chrono::{Duration, Utc};
use entity::hunter;
use jsonwebtoken::{Algorithm, EncodingKey, Header};
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::AuthClaims,
    state::{AppState, LiveKitConfig},
};

#[derive(Debug, Deserialize)]
pub struct VoiceTokenRequest {
    pub room_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct VoiceTokenResponse {
    pub url: String,
    pub room_id: String,
    pub token: String,
    pub identity: String,
    pub display_name: String,
    pub chat_topic: String,
    pub expires_in: i64,
}

#[derive(Debug, Serialize)]
struct LiveKitGrant {
    room: String,
    #[serde(rename = "roomJoin")]
    room_join: bool,
    #[serde(rename = "canPublish")]
    can_publish: bool,
    #[serde(rename = "canSubscribe")]
    can_subscribe: bool,
    #[serde(rename = "canPublishData")]
    can_publish_data: bool,
}

#[derive(Debug, Serialize)]
struct LiveKitTokenClaims {
    iss: String,
    sub: String,
    nbf: i64,
    exp: i64,
    name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    metadata: Option<String>,
    video: LiveKitGrant,
}

pub async fn issue_voice_token(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
    Json(payload): Json<VoiceTokenRequest>,
) -> AppResult<Json<VoiceTokenResponse>> {
    let livekit = state
        .livekit
        .as_ref()
        .ok_or_else(|| AppError::BadRequest("voice is not configured on server".into()))?;

    let hunter = hunter::Entity::find_by_id(claims.sub)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;

    let room_id = normalize_room_id(payload.room_id.as_deref(), claims.guild_id)?;
    let identity = format!("hunter:{}", hunter.player_id);
    let display_name = hunter.name;

    let token = encode_livekit_token(
        livekit,
        &identity,
        &display_name,
        &room_id,
        Some(format!(
            "{{\"guild_id\":\"{}\",\"hunter_id\":\"{}\"}}",
            claims.guild_id, claims.sub
        )),
    )?;

    Ok(Json(VoiceTokenResponse {
        url: livekit.url.clone(),
        room_id,
        token,
        identity,
        display_name,
        chat_topic: livekit.chat_topic.clone(),
        expires_in: livekit.token_ttl_seconds,
    }))
}

pub fn default_guild_voice_room(guild_id: Uuid) -> String {
    format!("guild_{guild_id}:campfire")
}

fn normalize_room_id(raw: Option<&str>, guild_id: Uuid) -> AppResult<String> {
    let default_room = default_guild_voice_room(guild_id);
    let room = raw.map(str::trim).unwrap_or_default();
    if room.is_empty() {
        return Ok(default_room);
    }
    if room.chars().count() > 96 {
        return Err(AppError::BadRequest("room_id too long".into()));
    }

    let guild_prefix = format!("guild_{guild_id}");
    if !room.starts_with(&guild_prefix) {
        return Err(AppError::Forbidden(
            "room_id is outside current guild scope".into(),
        ));
    }
    Ok(room.to_string())
}

fn encode_livekit_token(
    livekit: &LiveKitConfig,
    identity: &str,
    display_name: &str,
    room_id: &str,
    metadata: Option<String>,
) -> AppResult<String> {
    let now = Utc::now();
    let exp = now + Duration::seconds(livekit.token_ttl_seconds);
    let claims = LiveKitTokenClaims {
        iss: livekit.api_key.clone(),
        sub: identity.to_string(),
        nbf: now.timestamp() - 5,
        exp: exp.timestamp(),
        name: display_name.to_string(),
        metadata,
        video: LiveKitGrant {
            room: room_id.to_string(),
            room_join: true,
            can_publish: true,
            can_subscribe: true,
            can_publish_data: true,
        },
    };

    jsonwebtoken::encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(livekit.api_secret.as_bytes()),
    )
    .map_err(|_| AppError::BadRequest("failed to issue livekit token".into()))
}

#[cfg(test)]
mod tests {
    use jsonwebtoken::{Algorithm, DecodingKey, Validation};
    use serde::Deserialize;
    use uuid::Uuid;

    use crate::{
        jwt::{AuthRole, Claims, GuildRole},
        state::LiveKitConfig,
    };

    use super::{default_guild_voice_room, encode_livekit_token, normalize_room_id};

    #[derive(Debug, Deserialize)]
    struct ClaimsProbe {
        iss: String,
        sub: String,
        name: String,
        video: VideoProbe,
    }

    #[derive(Debug, Deserialize)]
    struct VideoProbe {
        room: String,
        #[serde(rename = "roomJoin")]
        room_join: bool,
        #[serde(rename = "canPublishData")]
        can_publish_data: bool,
    }

    #[test]
    fn room_normalization_is_guild_scoped() {
        let guild = Uuid::new_v4();
        let room = normalize_room_id(None, guild).expect("default room");
        assert_eq!(room, default_guild_voice_room(guild));

        let err = normalize_room_id(Some("guild_other:campfire"), guild)
            .expect_err("cross guild room should fail");
        assert!(matches!(err, crate::error::AppError::Forbidden(_)));
    }

    #[test]
    fn livekit_token_contains_join_grants() {
        let cfg = LiveKitConfig {
            url: "ws://127.0.0.1:7880".to_string(),
            api_key: "devkey".to_string(),
            api_secret: "devsecret".to_string(),
            token_ttl_seconds: 3600,
            chat_topic: "guild.chat".to_string(),
        };
        let token = encode_livekit_token(
            &cfg,
            "hunter:alice",
            "Alice",
            "guild_room:campfire",
            Some("{}".to_string()),
        )
        .expect("token");

        let mut validation = Validation::new(Algorithm::HS256);
        validation.validate_exp = false;
        let decoded = jsonwebtoken::decode::<ClaimsProbe>(
            &token,
            &DecodingKey::from_secret(cfg.api_secret.as_bytes()),
            &validation,
        )
        .expect("decode");

        assert_eq!(decoded.claims.iss, "devkey");
        assert_eq!(decoded.claims.sub, "hunter:alice");
        assert_eq!(decoded.claims.name, "Alice");
        assert_eq!(decoded.claims.video.room, "guild_room:campfire");
        assert!(decoded.claims.video.room_join);
        assert!(decoded.claims.video.can_publish_data);
    }

    #[test]
    fn claims_example_still_compiles_with_player_shape() {
        let guild_id = Uuid::new_v4();
        let hunter_id = Uuid::new_v4();
        let claims = Claims {
            sub: hunter_id,
            role: AuthRole::Player,
            guild_role: GuildRole::Member,
            guild_id,
            hunter_id: Some(hunter_id),
            iat: 0,
            exp: 1,
        };
        assert_eq!(claims.guild_id, guild_id);
    }
}
