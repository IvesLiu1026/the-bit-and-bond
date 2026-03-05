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
                    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stat_category') THEN
                        CREATE TYPE stat_category AS ENUM ('STR', 'INT', 'AGI', 'CHA', 'VIT', 'NONE');
                    END IF;
                END
                $$;

                CREATE TABLE IF NOT EXISTS hunter_reward_ledger (
                    id UUID PRIMARY KEY,
                    hunter_id UUID NOT NULL REFERENCES hunters(id) ON UPDATE CASCADE ON DELETE CASCADE,
                    quest_id UUID NULL REFERENCES quests(id) ON UPDATE CASCADE ON DELETE SET NULL,
                    stat_category stat_category NOT NULL DEFAULT 'NONE',
                    gained_xp INTEGER NOT NULL,
                    gained_coins INTEGER NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_hunter_reward_ledger_hunter_created_at
                    ON hunter_reward_ledger (hunter_id, created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_hunter_reward_ledger_hunter_stat
                    ON hunter_reward_ledger (hunter_id, stat_category);
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
                DROP INDEX IF EXISTS idx_hunter_reward_ledger_hunter_stat;
                DROP INDEX IF EXISTS idx_hunter_reward_ledger_hunter_created_at;
                DROP TABLE IF EXISTS hunter_reward_ledger;
                "#,
            )
            .await?;
        Ok(())
    }
}
