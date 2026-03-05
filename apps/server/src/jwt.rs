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
    use uuid::Uuid;

    use super::{GuildRole, JwtService};

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
}
