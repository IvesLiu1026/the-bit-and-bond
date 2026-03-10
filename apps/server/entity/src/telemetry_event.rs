use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "telemetry_events")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub guild_id: Option<Uuid>,
    pub hunter_id: Option<Uuid>,
    pub event_name: String,
    pub status: Option<String>,
    pub source: String,
    pub platform: Option<String>,
    pub locale: Option<String>,
    pub app_version: Option<String>,
    pub session_id: Option<String>,
    pub properties_json: String,
    pub occurred_at: DateTimeWithTimeZone,
    pub created_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::guild::Entity",
        from = "Column::GuildId",
        to = "super::guild::Column::Id",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    Guild,
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::HunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    Hunter,
}

impl Related<super::guild::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Guild.def()
    }
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Hunter.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
