use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(Quests::Table)
                    .add_column(
                        ColumnDef::new(Quests::StatCategory)
                            .string_len(8)
                            .not_null()
                            .default("vit"),
                    )
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(Quests::Table)
                    .drop_column(Quests::StatCategory)
                    .to_owned(),
            )
            .await
    }
}

#[derive(DeriveIden)]
enum Quests {
    Table,
    StatCategory,
}
