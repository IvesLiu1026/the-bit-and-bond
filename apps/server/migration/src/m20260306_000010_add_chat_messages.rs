use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(ChatMessages::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(ChatMessages::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(ChatMessages::GuildId).uuid().not_null())
                    .col(
                        ColumnDef::new(ChatMessages::SenderHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(ChatMessages::RoomId)
                            .string_len(96)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(ChatMessages::ClientMessageId)
                            .uuid()
                            .not_null(),
                    )
                    .col(ColumnDef::new(ChatMessages::Content).text().not_null())
                    .col(
                        ColumnDef::new(ChatMessages::SentAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_chat_messages_guild")
                            .from(ChatMessages::Table, ChatMessages::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_chat_messages_sender_hunter")
                            .from(ChatMessages::Table, ChatMessages::SenderHunterId)
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
                    .name("idx_chat_messages_room_timeline")
                    .table(ChatMessages::Table)
                    .col(ChatMessages::GuildId)
                    .col(ChatMessages::RoomId)
                    .col(ChatMessages::SentAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_chat_messages_room_client_unique")
                    .table(ChatMessages::Table)
                    .col(ChatMessages::GuildId)
                    .col(ChatMessages::RoomId)
                    .col(ChatMessages::ClientMessageId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(ChatMessages::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum Guilds {
    Table,
    Id,
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    Id,
}

#[derive(DeriveIden)]
enum ChatMessages {
    Table,
    Id,
    GuildId,
    SenderHunterId,
    RoomId,
    ClientMessageId,
    Content,
    SentAt,
}
