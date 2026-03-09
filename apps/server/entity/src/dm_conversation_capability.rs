use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]
#[sea_orm(rs_type = "String", db_type = "String(StringLen::N(24))")]
#[serde(rename_all = "snake_case")]
pub enum DmEncryptionMode {
    #[sea_orm(string_value = "plaintext")]
    Plaintext,
    #[sea_orm(string_value = "encrypted")]
    Encrypted,
}

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "dm_conversation_capabilities")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub conversation_key: String,
    pub left_hunter_id: Uuid,
    pub right_hunter_id: Uuid,
    pub encryption_mode: DmEncryptionMode,
    pub upgraded_at: Option<DateTimeWithTimeZone>,
    pub last_handshake_at: Option<DateTimeWithTimeZone>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::LeftHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    LeftHunter,
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::RightHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    RightHunter,
}

impl ActiveModelBehavior for ActiveModel {}
