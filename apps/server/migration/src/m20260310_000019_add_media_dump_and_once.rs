use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(MediaAssets::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(MediaAssets::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(MediaAssets::GuildId).uuid().not_null())
                    .col(ColumnDef::new(MediaAssets::OwnerHunterId).uuid().not_null())
                    .col(
                        ColumnDef::new(MediaAssets::Mode)
                            .string_len(24)
                            .not_null()
                            .default("vault"),
                    )
                    .col(
                        ColumnDef::new(MediaAssets::StorageKey)
                            .string_len(255)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(MediaAssets::OriginalFilename)
                            .string_len(255)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(MediaAssets::MimeType)
                            .string_len(120)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(MediaAssets::ByteSize)
                            .big_integer()
                            .not_null(),
                    )
                    .col(ColumnDef::new(MediaAssets::Caption).string_len(280).null())
                    .col(
                        ColumnDef::new(MediaAssets::IsPhotoDumpReady)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(MediaAssets::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(MediaAssets::ExpiresAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_media_assets_guild")
                            .from(MediaAssets::Table, MediaAssets::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_media_assets_owner_hunter")
                            .from(MediaAssets::Table, MediaAssets::OwnerHunterId)
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
                    .name("idx_media_assets_storage_key_unique")
                    .table(MediaAssets::Table)
                    .col(MediaAssets::StorageKey)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_media_assets_owner_created")
                    .table(MediaAssets::Table)
                    .col(MediaAssets::OwnerHunterId)
                    .col(MediaAssets::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(MediaOnceDeliveries::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::MediaAssetId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::GuildId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::SenderHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::RecipientHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::RemainingViews)
                            .integer()
                            .not_null()
                            .default(1),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::OpenedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::ConsumedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::ExpiresAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::AccessTokenHash)
                            .string_len(120)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::AccessTokenExpiresAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .col(
                        ColumnDef::new(MediaOnceDeliveries::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_media_once_delivery_media")
                            .from(
                                MediaOnceDeliveries::Table,
                                MediaOnceDeliveries::MediaAssetId,
                            )
                            .to(MediaAssets::Table, MediaAssets::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_media_once_delivery_guild")
                            .from(MediaOnceDeliveries::Table, MediaOnceDeliveries::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_media_once_delivery_sender")
                            .from(
                                MediaOnceDeliveries::Table,
                                MediaOnceDeliveries::SenderHunterId,
                            )
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_media_once_delivery_recipient")
                            .from(
                                MediaOnceDeliveries::Table,
                                MediaOnceDeliveries::RecipientHunterId,
                            )
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
                    .name("idx_media_once_delivery_recipient_created")
                    .table(MediaOnceDeliveries::Table)
                    .col(MediaOnceDeliveries::RecipientHunterId)
                    .col(MediaOnceDeliveries::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_media_once_delivery_media_recipient_unique")
                    .table(MediaOnceDeliveries::Table)
                    .col(MediaOnceDeliveries::MediaAssetId)
                    .col(MediaOnceDeliveries::RecipientHunterId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(PhotoDumpExports::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(PhotoDumpExports::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(PhotoDumpExports::GuildId).uuid().not_null())
                    .col(
                        ColumnDef::new(PhotoDumpExports::OwnerHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PhotoDumpExports::Title)
                            .string_len(120)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PhotoDumpExports::Style)
                            .string_len(40)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PhotoDumpExports::AssetCount)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(
                        ColumnDef::new(PhotoDumpExports::AssetIdsJson)
                            .text()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(PhotoDumpExports::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_photo_dump_exports_guild")
                            .from(PhotoDumpExports::Table, PhotoDumpExports::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_photo_dump_exports_owner")
                            .from(PhotoDumpExports::Table, PhotoDumpExports::OwnerHunterId)
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
                    .name("idx_photo_dump_exports_owner_created")
                    .table(PhotoDumpExports::Table)
                    .col(PhotoDumpExports::OwnerHunterId)
                    .col(PhotoDumpExports::CreatedAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(PhotoDumpExports::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(MediaOnceDeliveries::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(MediaAssets::Table).to_owned())
            .await
    }
}

#[derive(DeriveIden)]
enum MediaAssets {
    Table,
    Id,
    GuildId,
    OwnerHunterId,
    Mode,
    StorageKey,
    OriginalFilename,
    MimeType,
    ByteSize,
    Caption,
    IsPhotoDumpReady,
    CreatedAt,
    ExpiresAt,
}

#[derive(DeriveIden)]
enum MediaOnceDeliveries {
    Table,
    Id,
    MediaAssetId,
    GuildId,
    SenderHunterId,
    RecipientHunterId,
    RemainingViews,
    OpenedAt,
    ConsumedAt,
    ExpiresAt,
    AccessTokenHash,
    AccessTokenExpiresAt,
    CreatedAt,
}

#[derive(DeriveIden)]
enum PhotoDumpExports {
    Table,
    Id,
    GuildId,
    OwnerHunterId,
    Title,
    Style,
    AssetCount,
    AssetIdsJson,
    CreatedAt,
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
