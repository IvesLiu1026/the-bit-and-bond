use std::env;

use chrono::{Duration, Utc};
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::{AppError, AppResult};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuthRole {
    Player,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum GuildRole {
    Master,
    #[default]
    Member,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: Uuid,
    pub role: AuthRole,
    #[serde(default)]
    pub guild_role: GuildRole,
    pub guild_id: Uuid,
    pub hunter_id: Option<Uuid>,
    pub iat: i64,
    pub exp: i64,
}

#[derive(Debug, Clone)]
pub struct IssuedToken {
    pub access_token: String,
    pub claims: Claims,
    pub expires_in: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayerPassQrClaims {
    pub sub: Uuid,
    pub guild_id: Uuid,
    pub player_id: String,
    pub hunter_tag: String,
    pub typ: String,
    pub iat: i64,
    pub exp: i64,
}

#[derive(Debug, Clone)]
pub struct IssuedPlayerPassQrToken {
    pub token: String,
    pub claims: PlayerPassQrClaims,
    pub expires_in: i64,
}

#[derive(Clone)]
pub struct JwtService {
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
    ttl_seconds: i64,
}

impl JwtService {
    pub fn from_env() -> AppResult<Self> {
        let secret = env::var("JWT_SECRET").map_err(|_| {
            AppError::BadRequest("JWT_SECRET environment variable is required".into())
        })?;

        if secret.trim().len() < 32 {
            return Err(AppError::BadRequest(
                "JWT_SECRET must be at least 32 characters".into(),
            ));
        }

        let ttl_seconds = env::var("JWT_TTL_SECONDS")
            .ok()
            .and_then(|v| v.parse::<i64>().ok())
            .unwrap_or(8 * 60 * 60);

        Ok(Self::new(secret.as_bytes(), ttl_seconds))
    }

    pub fn new(secret: &[u8], ttl_seconds: i64) -> Self {
        Self {
            encoding_key: EncodingKey::from_secret(secret),
            decoding_key: DecodingKey::from_secret(secret),
            ttl_seconds,
        }
    }

    pub fn issue_player_token(
        &self,
        hunter_id: Uuid,
        guild_id: Uuid,
        guild_role: GuildRole,
    ) -> AppResult<IssuedToken> {
        let now = Utc::now();
        let exp = now + Duration::seconds(self.ttl_seconds);
        let claims = Claims {
            sub: hunter_id,
            role: AuthRole::Player,
            guild_role,
            guild_id,
            hunter_id: Some(hunter_id),
            iat: now.timestamp(),
            exp: exp.timestamp(),
        };

        self.issue(claims)
    }

    pub fn decode(&self, token: &str) -> AppResult<Claims> {
        let mut validation = Validation::new(Algorithm::HS256);
        validation.validate_exp = true;

        jsonwebtoken::decode::<Claims>(token, &self.decoding_key, &validation)
            .map(|v| v.claims)
            .map_err(|_| AppError::Unauthorized("invalid or expired token".into()))
    }

    pub fn issue_player_pass_qr_token(
        &self,
        hunter_id: Uuid,
        guild_id: Uuid,
        player_id: &str,
        hunter_tag: &str,
        ttl_seconds: i64,
    ) -> AppResult<IssuedPlayerPassQrToken> {
        let expires_in = ttl_seconds.clamp(30, 3600);
        let now = Utc::now();
        let exp = now + Duration::seconds(expires_in);
        let claims = PlayerPassQrClaims {
            sub: hunter_id,
            guild_id,
            player_id: player_id.to_string(),
            hunter_tag: hunter_tag.to_string(),
            typ: "player_pass".to_string(),
            iat: now.timestamp(),
            exp: exp.timestamp(),
        };
        let token =
            jsonwebtoken::encode(&Header::new(Algorithm::HS256), &claims, &self.encoding_key)
                .map_err(|_| AppError::BadRequest("failed to issue player pass qr token".into()))?;

        Ok(IssuedPlayerPassQrToken {
            token,
            claims,
            expires_in,
        })
    }

    fn issue(&self, claims: Claims) -> AppResult<IssuedToken> {
        let token =
            jsonwebtoken::encode(&Header::new(Algorithm::HS256), &claims, &self.encoding_key)
                .map_err(|_| AppError::BadRequest("failed to issue jwt".into()))?;

        Ok(IssuedToken {
            access_token: token,
            expires_in: self.ttl_seconds,
            claims,
        })
    }
}

#[cfg(test)]
mod tests {
    use jsonwebtoken::{Algorithm, DecodingKey, Validation};
    use uuid::Uuid;

    use super::{GuildRole, JwtService, PlayerPassQrClaims};

    #[test]
    fn roundtrip_claims() {
        let svc = JwtService::new(b"0123456789abcdef0123456789abcdef", 3600);
        let user = Uuid::new_v4();
        let guild = Uuid::new_v4();
        let issued = svc
            .issue_player_token(user, guild, GuildRole::Master)
            .expect("issue");
        let decoded = svc.decode(&issued.access_token).expect("decode");

        assert_eq!(decoded.sub, user);
        assert_eq!(decoded.guild_id, guild);
        assert_eq!(decoded.role, super::AuthRole::Player);
        assert_eq!(decoded.hunter_id, Some(user));
        assert_eq!(decoded.guild_role, GuildRole::Master);
    }

    #[test]
    fn issue_player_pass_qr_token_roundtrip() {
        let secret = b"0123456789abcdef0123456789abcdef";
        let svc = JwtService::new(secret, 3600);
        let hunter_id = Uuid::new_v4();
        let guild_id = Uuid::new_v4();
        let issued = svc
            .issue_player_pass_qr_token(hunter_id, guild_id, "demo_member", "ID-DEMO_MEMBER", 300)
            .expect("issue pass qr token");

        let mut validation = Validation::new(Algorithm::HS256);
        validation.validate_exp = true;
        let decoded = jsonwebtoken::decode::<PlayerPassQrClaims>(
            &issued.token,
            &DecodingKey::from_secret(secret),
            &validation,
        )
        .expect("decode");

        assert_eq!(issued.expires_in, 300);
        assert_eq!(decoded.claims.sub, hunter_id);
        assert_eq!(decoded.claims.guild_id, guild_id);
        assert_eq!(decoded.claims.player_id, "demo_member");
        assert_eq!(decoded.claims.hunter_tag, "ID-DEMO_MEMBER");
        assert_eq!(decoded.claims.typ, "player_pass");
        assert!(decoded.claims.exp > decoded.claims.iat);
    }
}
