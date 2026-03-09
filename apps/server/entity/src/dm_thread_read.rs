use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "dm_thread_reads")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub hunter_id: Uuid,
    pub conversation_key: String,
    pub last_read_at: DateTimeWithTimeZone,
    pub updated_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::HunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Hunter,
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Hunter.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
