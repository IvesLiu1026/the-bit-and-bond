use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "hunter_inventories")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub hunter_id: Uuid,
    pub item_id: Uuid,
    pub quantity: i32,
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
    #[sea_orm(
        belongs_to = "super::guild_item::Entity",
        from = "Column::ItemId",
        to = "super::guild_item::Column::Id",
        on_update = "Cascade",
        on_delete = "Cascade"
    )]
    Item,
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Hunter.def()
    }
}

impl Related<super::guild_item::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Item.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
