use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};

use crate::error::{AppError, AppResult};

pub fn validate_pin_code(pin_code: &str) -> AppResult<String> {
    let normalized = pin_code.trim();
    if normalized.len() != 4 || !normalized.chars().all(|ch| ch.is_ascii_digit()) {
        return Err(AppError::BadRequest(
            "pin_code must be exactly 4 digits".into(),
        ));
    }
    Ok(normalized.to_string())
}

pub fn hash_pin_code(pin_code: &str) -> AppResult<String> {
    let normalized = validate_pin_code(pin_code)?;
    let salt = SaltString::generate(&mut OsRng);
    let hasher = Argon2::default();
    hasher
        .hash_password(normalized.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| AppError::BadRequest("failed to hash pin_code".into()))
}

pub fn verify_pin_code(pin_code: &str, stored_pin_code: &str) -> bool {
    let normalized = pin_code.trim();
    if !pin_looks_hashed(stored_pin_code) {
        return normalized == stored_pin_code;
    }
    let parsed = match PasswordHash::new(stored_pin_code) {
        Ok(hash) => hash,
        Err(_) => return false,
    };
    Argon2::default()
        .verify_password(normalized.as_bytes(), &parsed)
        .is_ok()
}

pub fn pin_looks_hashed(stored_pin_code: &str) -> bool {
    stored_pin_code.starts_with("$argon2")
}
