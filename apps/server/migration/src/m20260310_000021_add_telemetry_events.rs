use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(TelemetryEvents::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(TelemetryEvents::Id)
                            .uuid()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(TelemetryEvents::GuildId).uuid().null())
                    .col(ColumnDef::new(TelemetryEvents::HunterId).uuid().null())
                    .col(
                        ColumnDef::new(TelemetryEvents::EventName)
                            .string_len(80)
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::Status)
                            .string_len(24)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::Source)
                            .string_len(24)
                            .not_null()
                            .default("client"),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::Platform)
                            .string_len(24)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::Locale)
                            .string_len(16)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::AppVersion)
                            .string_len(32)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::SessionId)
                            .string_len(64)
                            .null(),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::PropertiesJson)
                            .text()
                            .not_null()
                            .default("{}"),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::OccurredAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(TelemetryEvents::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_telemetry_events_guild")
                            .from(TelemetryEvents::Table, TelemetryEvents::GuildId)
                            .to(Guilds::Table, Guilds::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::SetNull),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_telemetry_events_hunter")
                            .from(TelemetryEvents::Table, TelemetryEvents::HunterId)
                            .to(Hunters::Table, Hunters::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::SetNull),
                    )
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_telemetry_events_occurred")
                    .table(TelemetryEvents::Table)
                    .col(TelemetryEvents::OccurredAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_telemetry_events_name_occurred")
                    .table(TelemetryEvents::Table)
                    .col(TelemetryEvents::EventName)
                    .col(TelemetryEvents::OccurredAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_telemetry_events_guild_occurred")
                    .table(TelemetryEvents::Table)
                    .col(TelemetryEvents::GuildId)
                    .col(TelemetryEvents::OccurredAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_telemetry_events_hunter_occurred")
                    .table(TelemetryEvents::Table)
                    .col(TelemetryEvents::HunterId)
                    .col(TelemetryEvents::OccurredAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(
                Table::drop()
                    .table(TelemetryEvents::Table)
                    .if_exists()
                    .to_owned(),
            )
            .await
    }
}

#[derive(DeriveIden)]
enum TelemetryEvents {
    Table,
    Id,
    GuildId,
    HunterId,
    EventName,
    Status,
    Source,
    Platform,
    Locale,
    AppVersion,
    SessionId,
    PropertiesJson,
    OccurredAt,
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
