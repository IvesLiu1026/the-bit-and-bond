use axum::{
    extract::{FromRef, FromRequestParts},
    http::{header::AUTHORIZATION, request::Parts},
};
use entity::hunter;
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};

use crate::{
    error::{AppError, AppResult},
    jwt::{Claims, GuildRole},
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
        let mut claims = app_state.jwt.decode(token)?;

        let hunter_id = claims
            .hunter_id
            .ok_or_else(|| AppError::Unauthorized("token missing hunter_id".into()))?;
        let model = hunter::Entity::find_by_id(hunter_id)
            .filter(hunter::Column::GuildId.eq(claims.guild_id))
            .one(&app_state.db)
            .await?
            .ok_or_else(|| AppError::Unauthorized("hunter identity no longer exists".into()))?;

        claims.sub = model.id;
        claims.hunter_id = Some(model.id);
        claims.guild_id = model.guild_id;
        claims.role = crate::jwt::AuthRole::Player;
        claims.guild_role = if model.guild_role == "master" {
            GuildRole::Master
        } else {
            GuildRole::Member
        };

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
        if claims.guild_role != GuildRole::Master {
            return Err(AppError::Forbidden(
                "guild owner role required for this endpoint".into(),
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
        Ok(Self(AuthClaims::from_request_parts(parts, state).await?.0))
    }
}

pub fn require_guild_owner(claims: &Claims) -> AppResult<()> {
    if claims.guild_role != GuildRole::Master {
        return Err(AppError::Forbidden(
            "guild owner role required for this endpoint".into(),
        ));
    }
    Ok(())
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
