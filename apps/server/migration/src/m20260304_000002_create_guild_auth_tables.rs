use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Users::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(Users::Id).uuid().not_null().primary_key())
                    .col(ColumnDef::new(Users::Email).string_len(255).not_null())
                    .col(
                        ColumnDef::new(Users::PasswordHash)
                            .string_len(255)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Users::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_users_email_unique")
                    .table(Users::Table)
                    .col(Users::Email)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(Guilds::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(Guilds::Id).uuid().not_null().primary_key())
                    .col(ColumnDef::new(Guilds::Name).string_len(128).not_null())
                    .col(ColumnDef::new(Guilds::OwnerId).uuid().not_null())
                    .col(ColumnDef::new(Guilds::InviteCode).string_len(6).not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_guilds_owner_id")
                            .from(Guilds::Table, Guilds::OwnerId)
                            .to(Users::Table, Users::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_guilds_owner_unique")
                    .table(Guilds::Table)
                    .col(Guilds::OwnerId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_guilds_invite_code_unique")
                    .table(Guilds::Table)
                    .col(Guilds::InviteCode)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(Hunters::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(Hunters::Id).uuid().not_null().primary_key())
                    .col(ColumnDef::new(Hunters::GuildId).uuid().not_null())
                    .col(ColumnDef::new(Hunters::Name).string_len(64).not_null())
                    .col(
                        ColumnDef::new(Hunters::AvatarType)
                            .string_len(32)
                            .not_null()
                            .default("novice"),
                    )
                    .col(
                        ColumnDef::new(Hunters::Level)
                            .integer()
                            .not_null()
                            .default(1),
                    )
                    .col(ColumnDef::new(Hunters::Xp).integer().not_null().default(0))
                    .col(
                        ColumnDef::new(Hunters::Coins)
                            .integer()
                            .not_null()
                            .default(0),
                    )
                    .col(ColumnDef::new(Hunters::PinCode).string_len(4).not_null())
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_hunters_guild_id")
                            .from(Hunters::Table, Hunters::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_hunters_guild_pin_unique")
                    .table(Hunters::Table)
                    .col(Hunters::GuildId)
                    .col(Hunters::PinCode)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_hunters_guild_id")
                    .table(Hunters::Table)
                    .col(Hunters::GuildId)
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(Quests::Table)
                    .if_not_exists()
                    .col(ColumnDef::new(Quests::Id).uuid().not_null().primary_key())
                    .col(ColumnDef::new(Quests::GuildId).uuid().not_null())
                    .col(ColumnDef::new(Quests::Title).string_len(128).not_null())
                    .col(ColumnDef::new(Quests::Description).text())
                    .col(ColumnDef::new(Quests::RewardXp).integer().not_null())
                    .col(ColumnDef::new(Quests::RewardCoins).integer().not_null())
                    .col(
                        ColumnDef::new(Quests::Status)
                            .string_len(24)
                            .not_null()
                            .default("available"),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_quests_guild_id")
                            .from(Quests::Table, Quests::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_quests_guild_status")
                    .table(Quests::Table)
                    .col(Quests::GuildId)
                    .col(Quests::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Quests::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Hunters::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Guilds::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Users::Table).to_owned())
            .await?;
        Ok(())
    }
}

#[derive(DeriveIden)]
enum Users {
    Table,
    Id,
    Email,
    PasswordHash,
    CreatedAt,
}

#[derive(DeriveIden)]
enum Guilds {
    Table,
    Id,
    Name,
    OwnerId,
    InviteCode,
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    Id,
    GuildId,
    Name,
    AvatarType,
    Level,
    Xp,
    Coins,
    PinCode,
}

#[derive(DeriveIden)]
enum Quests {
    Table,
    Id,
    GuildId,
    Title,
    Description,
    RewardXp,
    RewardCoins,
    Status,
}
