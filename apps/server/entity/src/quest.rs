use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]
#[sea_orm(rs_type = "String", db_type = "Enum", enum_name = "stat_category")]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum QuestStatCategory {
    #[sea_orm(string_value = "STR")]
    Str,
    #[sea_orm(string_value = "INT")]
    Int,
    #[sea_orm(string_value = "AGI")]
    Agi,
    #[sea_orm(string_value = "VIT")]
    Vit,
    #[sea_orm(string_value = "CHA")]
    Cha,
    #[sea_orm(string_value = "NONE")]
    None,
}

#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]
#[sea_orm(rs_type = "String", db_type = "String(StringLen::N(24))")]
pub enum QuestStatus {
    #[sea_orm(string_value = "available")]
    Available,
    #[sea_orm(string_value = "pending_review")]
    PendingReview,
    #[sea_orm(string_value = "completed")]
    Completed,
}

#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]
#[sea_orm(rs_type = "String", db_type = "String(StringLen::N(24))")]
#[serde(rename_all = "snake_case")]
pub enum QuestCategory {
    #[sea_orm(string_value = "chore")]
    Chore,
    #[sea_orm(string_value = "study")]
    Study,
    #[sea_orm(string_value = "exam")]
    Exam,
    #[sea_orm(string_value = "habit")]
    Habit,
    #[sea_orm(string_value = "unknown")]
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]
#[sea_orm(rs_type = "String", db_type = "String(StringLen::N(24))")]
#[serde(rename_all = "snake_case")]
pub enum HabitCadence {
    #[sea_orm(string_value = "daily")]
    Daily,
    #[sea_orm(string_value = "weekly")]
    Weekly,
}

#[derive(Clone, Debug, PartialEq, Eq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "quests")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub guild_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub reward_xp: i32,
    pub reward_coins: i32,
    pub stat_category: QuestStatCategory,
    pub category: QuestCategory,
    pub assigned_hunter_id: Option<Uuid>,
    pub created_by_hunter_id: Option<Uuid>,
    pub cadence: Option<HabitCadence>,
    pub streak_count: i32,
    pub best_streak: i32,
    pub completions_count: i32,
    pub proof_note: Option<String>,
    pub proof_submitted_at: Option<DateTimeWithTimeZone>,
    pub last_completed_at: Option<Date>,
    pub last_review_note: Option<String>,
    pub updated_at: DateTimeWithTimeZone,
    pub status: QuestStatus,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
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
        from = "Column::AssignedHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    AssignedHunter,
    #[sea_orm(
        belongs_to = "super::hunter::Entity",
        from = "Column::CreatedByHunterId",
        to = "super::hunter::Column::Id",
        on_update = "Cascade",
        on_delete = "SetNull"
    )]
    CreatedByHunter,
}

impl Related<super::guild::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Guild.def()
    }
}

impl Related<super::hunter::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::AssignedHunter.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
