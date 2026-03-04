use axum::{
    extract::{FromRef, FromRequestParts},
    http::{header::AUTHORIZATION, request::Parts},
};

use crate::{
    error::{AppError, AppResult},
    jwt::{AuthRole, Claims},
    state::AppState,
};

#[derive(Debug, Clone)]
pub struct AuthClaims(pub Claims);

impl<S> FromRequestParts<S> for AuthClaims
where
    S: Send + Sync,
    AppState: FromRef<S>,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = bearer_token(parts)?;
        let app_state = AppState::from_ref(state);
        let claims = app_state.jwt.decode(token)?;
        Ok(Self(claims))
    }
}

#[derive(Debug, Clone)]
pub struct GuildMasterClaims(pub Claims);

impl<S> FromRequestParts<S> for GuildMasterClaims
where
    S: Send + Sync,
    AppState: FromRef<S>,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let claims = AuthClaims::from_request_parts(parts, state).await?.0;
        if claims.role != AuthRole::GuildMaster {
            return Err(AppError::Forbidden(
                "guild_master role required for this endpoint".into(),
            ));
        }
        Ok(Self(claims))
    }
}

#[derive(Debug, Clone)]
pub struct HunterClaims(pub Claims);

impl<S> FromRequestParts<S> for HunterClaims
where
    S: Send + Sync,
    AppState: FromRef<S>,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let claims = AuthClaims::from_request_parts(parts, state).await?.0;
        if claims.role != AuthRole::Hunter {
            return Err(AppError::Forbidden(
                "hunter role required for this endpoint".into(),
            ));
        }
        Ok(Self(claims))
    }
}

fn bearer_token(parts: &Parts) -> AppResult<&str> {
    let raw = parts
        .headers
        .get(AUTHORIZATION)
        .ok_or_else(|| AppError::Unauthorized("missing Authorization header".into()))?
        .to_str()
        .map_err(|_| AppError::Unauthorized("invalid Authorization header".into()))?;

    raw.strip_prefix("Bearer ")
        .ok_or_else(|| AppError::Unauthorized("Authorization must be a Bearer token".into()))
}
