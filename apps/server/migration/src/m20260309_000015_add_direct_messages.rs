use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(DirectMessages::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(DirectMessages::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(DirectMessages::SenderHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DirectMessages::RecipientHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DirectMessages::ConversationKey)
                            .string_len(80)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(DirectMessages::ClientMessageId)
                            .uuid()
                            .not_null(),
                    )
                    .col(ColumnDef::new(DirectMessages::Content).text().not_null())
                    .col(
                        ColumnDef::new(DirectMessages::SentAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_direct_messages_sender_hunter")
                            .from(DirectMessages::Table, DirectMessages::SenderHunterId)
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_direct_messages_recipient_hunter")
                            .from(DirectMessages::Table, DirectMessages::RecipientHunterId)
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
                    .name("idx_direct_messages_conversation_timeline")
                    .table(DirectMessages::Table)
                    .col(DirectMessages::ConversationKey)
                    .col(DirectMessages::SentAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_direct_messages_hunter_timeline")
                    .table(DirectMessages::Table)
                    .col(DirectMessages::SenderHunterId)
                    .col(DirectMessages::RecipientHunterId)
                    .col(DirectMessages::SentAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_direct_messages_conversation_client_unique")
                    .table(DirectMessages::Table)
                    .col(DirectMessages::ConversationKey)
                    .col(DirectMessages::ClientMessageId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(DirectMessages::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    Id,
}

#[derive(DeriveIden)]
enum DirectMessages {
    Table,
    Id,
    SenderHunterId,
    RecipientHunterId,
    ConversationKey,
    ClientMessageId,
    Content,
    SentAt,
}
