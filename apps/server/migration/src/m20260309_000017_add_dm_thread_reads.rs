use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(DmThreadReads::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(DmThreadReads::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(DmThreadReads::HunterId).uuid().not_null())
                    .col(
                        ColumnDef::new(DmThreadReads::ConversationKey)
                            .string_len(80)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DmThreadReads::LastReadAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(DmThreadReads::UpdatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_dm_thread_reads_hunter")
                            .from(DmThreadReads::Table, DmThreadReads::HunterId)
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_dm_thread_reads_hunter_conversation_unique")
                    .table(DmThreadReads::Table)
                    .col(DmThreadReads::HunterId)
                    .col(DmThreadReads::ConversationKey)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_dm_thread_reads_hunter_updated")
                    .table(DmThreadReads::Table)
                    .col(DmThreadReads::HunterId)
                    .col(DmThreadReads::UpdatedAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(DmThreadReads::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    Id,
}

#[derive(DeriveIden)]
enum DmThreadReads {
    Table,
    Id,
    HunterId,
    ConversationKey,
    LastReadAt,
    UpdatedAt,
}
