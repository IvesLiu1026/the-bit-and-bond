pub use sea_orm_migration::prelude::*;

mod m20260304_000001_create_core_tables;
mod m20260304_000002_create_guild_auth_tables;
mod m20260305_000003_add_player_id_and_social_tables;
mod m20260305_000004_add_user_tag_and_friend_requests;
mod m20260305_000005_add_hunter_owner_role;
mod m20260305_000006_add_hunter_motto;
mod m20260305_000007_add_quest_stat_category;
mod m20260305_000008_hash_hunter_pin_codes;
mod m20260306_000009_quest_stat_category_enum;
mod m20260306_000010_add_chat_messages;
mod m20260306_000011_add_hunter_reward_ledger;
mod m20260306_000012_add_shop_and_ledger_v2;
mod m20260306_000013_add_shop_item_is_active;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20260304_000001_create_core_tables::Migration),
            Box::new(m20260304_000002_create_guild_auth_tables::Migration),
            Box::new(m20260305_000003_add_player_id_and_social_tables::Migration),
            Box::new(m20260305_000004_add_user_tag_and_friend_requests::Migration),
            Box::new(m20260305_000005_add_hunter_owner_role::Migration),
            Box::new(m20260305_000006_add_hunter_motto::Migration),
            Box::new(m20260305_000007_add_quest_stat_category::Migration),
            Box::new(m20260305_000008_hash_hunter_pin_codes::Migration),
            Box::new(m20260306_000009_quest_stat_category_enum::Migration),
            Box::new(m20260306_000010_add_chat_messages::Migration),
            Box::new(m20260306_000011_add_hunter_reward_ledger::Migration),
            Box::new(m20260306_000012_add_shop_and_ledger_v2::Migration),
            Box::new(m20260306_000013_add_shop_item_is_active::Migration),
        ]
    }
}
