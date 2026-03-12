use entity::{dm_device_key, friend_link};
use sea_orm::{ColumnTrait, ConnectionTrait, EntityTrait, QueryFilter};
use uuid::Uuid;

use crate::error::{AppError, AppResult};

pub async fn require_friend_link<C: ConnectionTrait>(
    db: &C,
    source_hunter_id: Uuid,
    target_hunter_id: Uuid,
    forbidden_message: &str,
) -> AppResult<()> {
    let is_friend = friend_link::Entity::find()
        .filter(friend_link::Column::PlayerId.eq(source_hunter_id))
        .filter(friend_link::Column::FriendId.eq(target_hunter_id))
        .one(db)
        .await?
        .is_some();
    if is_friend {
        return Ok(());
    }
    Err(AppError::Forbidden(forbidden_message.into()))
}

pub async fn require_active_dm_device_key<C: ConnectionTrait>(
    db: &C,
    hunter_id: Uuid,
    device_id: &str,
) -> AppResult<dm_device_key::Model> {
    dm_device_key::Entity::find()
        .filter(dm_device_key::Column::HunterId.eq(hunter_id))
        .filter(dm_device_key::Column::DeviceId.eq(device_id.to_string()))
        .filter(dm_device_key::Column::RevokedAt.is_null())
        .one(db)
        .await?
        .ok_or_else(|| AppError::BadRequest(format!("active device key not found for {device_id}")))
}
