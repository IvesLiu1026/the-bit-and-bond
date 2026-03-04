use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "guilds")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub name: String,
    pub owner_id: Uuid,
    pub invite_code: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::user::Entity",
        from = "Column::OwnerId",
        to = "super::user::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Owner,
    #[sea_orm(has_many = "super::hunter::Entity")]
    Hunters,
    #[sea_orm(has_many = "super::quest::Entity")]
    Quests,
}

impl Related<super::user::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Owner.def()
    }
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Hunters.def()
    }
}

impl Related<super::quest::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Quests.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
