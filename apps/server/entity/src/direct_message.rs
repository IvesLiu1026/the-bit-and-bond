use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "direct_messages")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub sender_hunter_id: Uuid,
    pub recipient_hunter_id: Uuid,
    pub conversation_key: String,
    pub client_message_id: Uuid,
    pub content: String,
    pub sent_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
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

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::SenderHunter.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
