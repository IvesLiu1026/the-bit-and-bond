use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "media_once_deliveries")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub media_asset_id: Uuid,
    pub guild_id: Uuid,
    pub sender_hunter_id: Uuid,
    pub recipient_hunter_id: Uuid,
    pub remaining_views: i32,
    pub opened_at: Option<DateTimeWithTimeZone>,
    pub consumed_at: Option<DateTimeWithTimeZone>,
    pub expires_at: Option<DateTimeWithTimeZone>,
    pub access_token_hash: Option<String>,
    pub access_token_expires_at: Option<DateTimeWithTimeZone>,
    pub encryption_mode: String,
    pub protocol_version: Option<String>,
    pub sender_device_id: Option<String>,
    pub recipient_device_id: Option<String>,
    pub encryption_nonce: Option<String>,
    pub encryption_mac: Option<String>,
    pub created_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::media_asset::Entity",
        from = "Column::MediaAssetId",
        to = "super::media_asset::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    MediaAsset,
    #[sea_orm(
        belongs_to = "super::guild::Entity",
        from = "Column::GuildId",
        to = "super::guild::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Guild,
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::SenderHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    SenderHunter,
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::RecipientHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    RecipientHunter,
}

impl Related<super::media_asset::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::MediaAsset.def()
    }
}

impl Related<super::guild::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Guild.def()
    }
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SenderHunter.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
