use crate::error::{AppError, AppResult};

pub const PLAYER_ID_MIN_LEN: usize = 4;
pub const PLAYER_ID_MAX_LEN: usize = 24;

pub fn normalize_player_id_with_messages(
    raw: &str,
    length_error: &str,
    charset_error: &str,
) -> AppResult<String> {
    let normalized = raw.trim().to_ascii_lowercase();
    if normalized.len() < PLAYER_ID_MIN_LEN || normalized.len() > PLAYER_ID_MAX_LEN {
        return Err(AppError::BadRequest(length_error.into()));
    }
    if !normalized
        .chars()
        .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_')
    {
        return Err(AppError::BadRequest(charset_error.into()));
    }
    Ok(normalized)
}
