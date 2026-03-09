use std::collections::HashMap;

use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};
use serde::Deserialize;

use crate::error::{AppError, AppResult};

const FIREBASE_CERTS_URL: &str =
    "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

#[derive(Debug, Clone)]
pub struct FirebaseIdentity {
    pub uid: String,
    pub email: String,
    pub display_name: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
struct FirebaseJwtClaims {
    aud: String,
    iss: String,
    sub: String,
    email: Option<String>,
    email_verified: Option<bool>,
    name: Option<String>,
    exp: usize,
}

pub async fn verify_firebase_id_token(
    project_id: &str,
    id_token: &str,
) -> AppResult<FirebaseIdentity> {
    let kid = decode_header(id_token)
        .map_err(|_| AppError::Unauthorized("invalid firebase token header".into()))?
        .kid
        .ok_or_else(|| AppError::Unauthorized("firebase token missing key id".into()))?;

    let certs = reqwest::Client::new()
        .get(FIREBASE_CERTS_URL)
        .send()
        .await
        .map_err(|_| {
            AppError::ServiceUnavailable("firebase cert fetch failed, please retry".into())
        })?
        .error_for_status()
        .map_err(|_| {
            AppError::ServiceUnavailable("firebase cert fetch failed, please retry".into())
        })?
        .json::<HashMap<String, String>>()
        .await
        .map_err(|_| AppError::ServiceUnavailable("firebase cert parse failed".into()))?;

    let cert_pem = certs
        .get(&kid)
        .ok_or_else(|| AppError::Unauthorized("firebase token key is unknown".into()))?;

    let issuer = format!("https://securetoken.google.com/{project_id}");
    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[project_id]);
    validation.set_issuer(&[issuer.as_str()]);
    validation
        .required_spec_claims
        .extend(["exp".into(), "sub".into()]);

    let token = decode::<FirebaseJwtClaims>(
        id_token,
        &DecodingKey::from_rsa_pem(cert_pem.as_bytes())
            .map_err(|_| AppError::Unauthorized("invalid firebase cert".into()))?,
        &validation,
    )
    .map_err(|_| AppError::Unauthorized("firebase token verification failed".into()))?;

    let claims = token.claims;
    if claims.aud != project_id || claims.iss != issuer {
        return Err(AppError::Unauthorized(
            "firebase token audience mismatch".into(),
        ));
    }
    if claims.exp == 0 {
        return Err(AppError::Unauthorized("firebase token expired".into()));
    }
    if claims.sub.trim().is_empty() {
        return Err(AppError::Unauthorized(
            "firebase token subject missing".into(),
        ));
    }
    if claims.email_verified != Some(true) {
        return Err(AppError::Unauthorized(
            "google account email must be verified".into(),
        ));
    }

    let email = claims
        .email
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| AppError::Unauthorized("firebase token missing email".into()))?
        .to_ascii_lowercase();

    Ok(FirebaseIdentity {
        uid: claims.sub,
        email,
        display_name: claims
            .name
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned),
    })
}
