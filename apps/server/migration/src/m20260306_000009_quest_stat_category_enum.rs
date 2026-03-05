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
                "#,
            )
            .await?;

        manager
            .get_connection()
            .execute_unprepared(
                r#"
                ALTER TABLE quests
                  ADD COLUMN stat_category_new stat_category NOT NULL DEFAULT 'NONE';

                UPDATE quests
                SET stat_category_new = CASE UPPER(COALESCE(stat_category::text, ''))
                  WHEN 'STR' THEN 'STR'::stat_category
                  WHEN 'INT' THEN 'INT'::stat_category
                  WHEN 'AGI' THEN 'AGI'::stat_category
                  WHEN 'CHA' THEN 'CHA'::stat_category
                  WHEN 'VIT' THEN 'VIT'::stat_category
                  WHEN 'NONE' THEN 'NONE'::stat_category
                  ELSE 'NONE'::stat_category
                END;

                ALTER TABLE quests DROP COLUMN stat_category;
                ALTER TABLE quests RENAME COLUMN stat_category_new TO stat_category;
                ALTER TABLE quests ALTER COLUMN stat_category SET DEFAULT 'NONE';
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
                ALTER TABLE quests
                  ADD COLUMN stat_category_text VARCHAR(8) NOT NULL DEFAULT 'none';

                UPDATE quests
                SET stat_category_text = LOWER(stat_category::text);

                ALTER TABLE quests DROP COLUMN stat_category;
                ALTER TABLE quests RENAME COLUMN stat_category_text TO stat_category;
                ALTER TABLE quests ALTER COLUMN stat_category SET DEFAULT 'none';

                DROP TYPE IF EXISTS stat_category;
                "#,
            )
            .await?;
        Ok(())
    }
}
