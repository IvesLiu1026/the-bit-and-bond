use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .get_connection()
            .execute_unprepared(
                r#"
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ledger_event_type') THEN
                        CREATE TYPE ledger_event_type AS ENUM ('quest_reward', 'shop_purchase', 'adjustment');
                    END IF;
                END
                $$;

                CREATE TABLE IF NOT EXISTS guild_items (
                    id UUID PRIMARY KEY,
                    guild_id UUID NOT NULL REFERENCES guilds(id) ON UPDATE CASCADE ON DELETE CASCADE,
                    name VARCHAR(64) NOT NULL,
                    description TEXT NULL,
                    cost_coins INTEGER NOT NULL CHECK (cost_coins >= 0),
                    icon_tag VARCHAR(32) NOT NULL
                );

                CREATE UNIQUE INDEX IF NOT EXISTS idx_guild_items_guild_name_unique
                    ON guild_items (guild_id, name);

                ALTER TABLE hunter_reward_ledger
                    ADD COLUMN IF NOT EXISTS event_type ledger_event_type NOT NULL DEFAULT 'quest_reward',
                    ADD COLUMN IF NOT EXISTS item_id UUID NULL,
                    ADD COLUMN IF NOT EXISTS idempotency_key UUID NULL;

                ALTER TABLE hunter_reward_ledger
                    DROP CONSTRAINT IF EXISTS fk_hunter_reward_ledger_item;
                ALTER TABLE hunter_reward_ledger
                    ADD CONSTRAINT fk_hunter_reward_ledger_item
                    FOREIGN KEY (item_id) REFERENCES guild_items(id)
                    ON UPDATE CASCADE
                    ON DELETE SET NULL
                    DEFERRABLE INITIALLY DEFERRED;

                CREATE UNIQUE INDEX IF NOT EXISTS idx_hunter_reward_ledger_hunter_idempotency
                    ON hunter_reward_ledger (hunter_id, idempotency_key)
                    WHERE idempotency_key IS NOT NULL;

                CREATE TABLE IF NOT EXISTS hunter_inventories (
                    id UUID PRIMARY KEY,
                    hunter_id UUID NOT NULL REFERENCES hunters(id) ON UPDATE CASCADE ON DELETE CASCADE,
                    item_id UUID NOT NULL REFERENCES guild_items(id) ON UPDATE CASCADE ON DELETE CASCADE,
                    quantity INTEGER NOT NULL CHECK (quantity >= 0),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE UNIQUE INDEX IF NOT EXISTS idx_hunter_inventories_hunter_item_unique
                    ON hunter_inventories (hunter_id, item_id);
                "#,
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .get_connection()
            .execute_unprepared(
                r#"
                DROP INDEX IF EXISTS idx_hunter_inventories_hunter_item_unique;
                DROP TABLE IF EXISTS hunter_inventories;

                DROP INDEX IF EXISTS idx_hunter_reward_ledger_hunter_idempotency;
                ALTER TABLE hunter_reward_ledger
                    DROP CONSTRAINT IF EXISTS fk_hunter_reward_ledger_item;
                ALTER TABLE hunter_reward_ledger
                    DROP COLUMN IF EXISTS idempotency_key,
                    DROP COLUMN IF EXISTS item_id,
                    DROP COLUMN IF EXISTS event_type;

                DROP INDEX IF EXISTS idx_guild_items_guild_name_unique;
                DROP TABLE IF EXISTS guild_items;

                DROP TYPE IF EXISTS ledger_event_type;
                "#,
            )
            .await?;
        Ok(())
    }
}
