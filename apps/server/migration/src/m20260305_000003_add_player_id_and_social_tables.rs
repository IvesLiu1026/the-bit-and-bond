use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .add_column(ColumnDef::new(Hunters::PlayerId).string_len(32).null())
                    .to_owned(),
            )
            .await?;

        manager
            .get_connection()
            .execute_unprepared(
                r#"
                UPDATE hunters
                SET player_id = CONCAT('P', SUBSTRING(REPLACE(id::text, '-', '') FROM 1 FOR 10))
                WHERE player_id IS NULL OR player_id = '';
                "#,
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .modify_column(ColumnDef::new(Hunters::PlayerId).string_len(32).not_null())
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_hunters_player_id_unique")
                    .table(Hunters::Table)
                    .col(Hunters::PlayerId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(FriendLinks::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FriendLinks::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(FriendLinks::PlayerId).uuid().not_null())
                    .col(ColumnDef::new(FriendLinks::FriendId).uuid().not_null())
                    .col(
                        ColumnDef::new(FriendLinks::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_friend_links_player_id")
                            .from(FriendLinks::Table, FriendLinks::PlayerId)
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_friend_links_friend_id")
                            .from(FriendLinks::Table, FriendLinks::FriendId)
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
                    .name("idx_friend_links_pair_unique")
                    .table(FriendLinks::Table)
                    .col(FriendLinks::PlayerId)
                    .col(FriendLinks::FriendId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_friend_links_friend_id")
                    .table(FriendLinks::Table)
                    .col(FriendLinks::FriendId)
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(GuildInvites::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(GuildInvites::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(GuildInvites::GuildId).uuid().not_null())
                    .col(
                        ColumnDef::new(GuildInvites::InviterHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(GuildInvites::InvitedHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(GuildInvites::Status)
                            .string_len(24)
                            .not_null()
                            .default("pending"),
                    )
                    .col(
                        ColumnDef::new(GuildInvites::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(GuildInvites::RespondedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_guild_invites_guild_id")
                            .from(GuildInvites::Table, GuildInvites::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_guild_invites_inviter")
                            .from(GuildInvites::Table, GuildInvites::InviterHunterId)
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_guild_invites_invited")
                            .from(GuildInvites::Table, GuildInvites::InvitedHunterId)
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
                    .name("idx_guild_invites_invited_status")
                    .table(GuildInvites::Table)
                    .col(GuildInvites::InvitedHunterId)
                    .col(GuildInvites::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(GuildInvites::Table).to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(FriendLinks::Table).to_owned())
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_hunters_player_id_unique")
                    .table(Hunters::Table)
                    .to_owned(),
            )
            .await?;
        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .drop_column(Hunters::PlayerId)
                    .to_owned(),
            )
            .await?;
        Ok(())
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
    PlayerId,
}

#[derive(DeriveIden)]
enum FriendLinks {
    Table,
    Id,
    PlayerId,
    FriendId,
    CreatedAt,
}

#[derive(DeriveIden)]
enum GuildInvites {
    Table,
    Id,
    GuildId,
    InviterHunterId,
    InvitedHunterId,
    Status,
    CreatedAt,
    RespondedAt,
}
