use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(QuestProofMedia::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(QuestProofMedia::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(QuestProofMedia::QuestId).uuid().not_null())
                    .col(ColumnDef::new(QuestProofMedia::GuildId).uuid().not_null())
                    .col(
                        ColumnDef::new(QuestProofMedia::UploadedByHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(QuestProofMedia::StorageKey)
                            .string_len(255)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(QuestProofMedia::OriginalFilename)
                            .string_len(255)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(QuestProofMedia::MimeType)
                            .string_len(120)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(QuestProofMedia::ByteSize)
                            .big_integer()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(QuestProofMedia::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_quest_proof_media_quest")
                            .from(QuestProofMedia::Table, QuestProofMedia::QuestId)
                            .to(Quests::Table, Quests::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_quest_proof_media_guild")
                            .from(QuestProofMedia::Table, QuestProofMedia::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_quest_proof_media_uploaded_by_hunter")
                            .from(QuestProofMedia::Table, QuestProofMedia::UploadedByHunterId)
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
                    .name("idx_quest_proof_media_quest_created")
                    .table(QuestProofMedia::Table)
                    .col(QuestProofMedia::QuestId)
                    .col(QuestProofMedia::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_quest_proof_media_guild_created")
                    .table(QuestProofMedia::Table)
                    .col(QuestProofMedia::GuildId)
                    .col(QuestProofMedia::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_quest_proof_media_storage_key_unique")
                    .table(QuestProofMedia::Table)
                    .col(QuestProofMedia::StorageKey)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(QuestProofMedia::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum QuestProofMedia {
    Table,
    Id,
    QuestId,
    GuildId,
    UploadedByHunterId,
    StorageKey,
    OriginalFilename,
    MimeType,
    ByteSize,
    CreatedAt,
}

#[derive(DeriveIden)]
enum Quests {
    Table,
    Id,
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
