use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

use super::quest::QuestStatCategory;

#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]
#[sea_orm(rs_type = "String", db_type = "Enum", enum_name = "ledger_event_type")]
#[serde(rename_all = "snake_case")]
pub enum LedgerEventType {
    #[sea_orm(string_value = "quest_reward")]
    QuestReward,
    #[sea_orm(string_value = "shop_purchase")]
    ShopPurchase,
    #[sea_orm(string_value = "adjustment")]
    Adjustment,
}

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "hunter_reward_ledger")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub hunter_id: Uuid,
    pub quest_id: Option<Uuid>,
    pub item_id: Option<Uuid>,
    pub idempotency_key: Option<Uuid>,
    pub event_type: LedgerEventType,
    pub stat_category: QuestStatCategory,
    pub gained_xp: i32,
    pub gained_coins: i32,
    pub created_at: DateTimeWithTimeZone,
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
        belongs_to = "super::quest::Entity",
        from = "Column::QuestId",
        to = "super::quest::Column::Id",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    Quest,
    #[sea_orm(
        belongs_to = "super::guild_item::Entity",
        from = "Column::ItemId",
        to = "super::guild_item::Column::Id",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    Item,
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Hunter.def()
    }
}

impl Related<super::quest::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Quest.def()
    }
}

impl Related<super::guild_item::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Item.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
