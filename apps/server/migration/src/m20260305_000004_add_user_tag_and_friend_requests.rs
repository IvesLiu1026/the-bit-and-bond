use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(Users::Table)
                    .add_column(ColumnDef::new(Users::HunterTag).string_len(32).null())
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Users::Table)
                    .add_column(ColumnDef::new(Users::CurrentRole).string_len(32).null())
                    .to_owned(),
            )
            .await?;

        manager
            .get_connection()
            .execute_unprepared(
                r#"
                UPDATE users
                SET
                  "hunter_tag" = CONCAT('ID-', UPPER(SUBSTRING(REPLACE(id::text, '-', '') FROM 1 FOR 6))),
                  "current_role" = 'Guardian'
                WHERE "hunter_tag" IS NULL OR "current_role" IS NULL;
                "#,
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Users::Table)
                    .modify_column(
                        ColumnDef::new(Users::HunterTag)
                            .string_len(32)
                            .not_null()
                            .default("ID-UNKNOWN"),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Users::Table)
                    .modify_column(
                        ColumnDef::new(Users::CurrentRole)
                            .string_len(32)
                            .not_null()
                            .default("Explorer"),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_users_hunter_tag_unique")
                    .table(Users::Table)
                    .col(Users::HunterTag)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_table(
                Table::create()
                    .table(FriendRequests::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(FriendRequests::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(FriendRequests::RequesterHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FriendRequests::TargetHunterId)
                            .uuid()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(FriendRequests::Status)
                            .string_len(24)
                            .not_null()
                            .default("pending"),
                    )
                    .col(
                        ColumnDef::new(FriendRequests::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(FriendRequests::RespondedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_friend_requests_requester")
                            .from(FriendRequests::Table, FriendRequests::RequesterHunterId)
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_friend_requests_target")
                            .from(FriendRequests::Table, FriendRequests::TargetHunterId)
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
                    .name("idx_friend_requests_pair_unique")
                    .table(FriendRequests::Table)
                    .col(FriendRequests::RequesterHunterId)
                    .col(FriendRequests::TargetHunterId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_friend_requests_target_status")
                    .table(FriendRequests::Table)
                    .col(FriendRequests::TargetHunterId)
                    .col(FriendRequests::Status)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(FriendRequests::Table).to_owned())
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_users_hunter_tag_unique")
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;
        manager
            .alter_table(
                Table::alter()
                    .table(Users::Table)
                    .drop_column(Users::HunterTag)
                    .to_owned(),
            )
            .await?;
        manager
            .alter_table(
                Table::alter()
                    .table(Users::Table)
                    .drop_column(Users::CurrentRole)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }
}

#[derive(DeriveIden)]
enum Users {
    Table,
    HunterTag,
    CurrentRole,
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    Id,
}

#[derive(DeriveIden)]
enum FriendRequests {
    Table,
    Id,
    RequesterHunterId,
    TargetHunterId,
    Status,
    CreatedAt,
    RespondedAt,
}
