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
                ALTER TABLE quests
                    ADD COLUMN category VARCHAR(24) NOT NULL DEFAULT 'chore',
                    ADD COLUMN assigned_hunter_id UUID NULL REFERENCES hunters(id) ON UPDATE CASCADE ON DELETE SET NULL,
                    ADD COLUMN created_by_hunter_id UUID NULL REFERENCES hunters(id) ON UPDATE CASCADE ON DELETE SET NULL,
                    ADD COLUMN cadence VARCHAR(24) NULL,
                    ADD COLUMN streak_count INTEGER NOT NULL DEFAULT 0,
                    ADD COLUMN best_streak INTEGER NOT NULL DEFAULT 0,
                    ADD COLUMN completions_count INTEGER NOT NULL DEFAULT 0,
                    ADD COLUMN proof_note TEXT NULL,
                    ADD COLUMN proof_submitted_at TIMESTAMPTZ NULL,
                    ADD COLUMN last_completed_at DATE NULL,
                    ADD COLUMN last_review_note TEXT NULL,
                    ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP;

                CREATE INDEX idx_quests_guild_category
                    ON quests (guild_id, category);

                CREATE INDEX idx_quests_assigned_status
                    ON quests (assigned_hunter_id, status);
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
                DROP INDEX IF EXISTS idx_quests_assigned_status;
                DROP INDEX IF EXISTS idx_quests_guild_category;

                ALTER TABLE quests
                    DROP COLUMN updated_at,
                    DROP COLUMN last_review_note,
                    DROP COLUMN last_completed_at,
                    DROP COLUMN proof_submitted_at,
                    DROP COLUMN proof_note,
                    DROP COLUMN completions_count,
                    DROP COLUMN best_streak,
                    DROP COLUMN streak_count,
                    DROP COLUMN cadence,
                    DROP COLUMN created_by_hunter_id,
                    DROP COLUMN assigned_hunter_id,
                    DROP COLUMN category;
                "#,
            )
            .await?;
        Ok(())
    }
}
