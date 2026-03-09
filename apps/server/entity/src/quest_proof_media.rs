use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "quest_proof_media")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub quest_id: Uuid,
    pub guild_id: Uuid,
    pub uploaded_by_hunter_id: Uuid,
    pub storage_key: String,
    pub original_filename: Option<String>,
    pub mime_type: String,
    pub byte_size: i64,
    pub created_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::quest::Entity",
        from = "Column::QuestId",
        to = "super::quest::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Quest,
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
        from = "Column::UploadedByHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    UploadedByHunter,
}

impl Related<super::quest::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Quest.def()
    }
}

impl Related<super::guild::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Guild.def()
    }
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::UploadedByHunter.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
