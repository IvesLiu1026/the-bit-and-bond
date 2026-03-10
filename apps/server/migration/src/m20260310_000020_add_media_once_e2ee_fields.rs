use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(MediaOnceDeliveries::Table)
                    .add_column(
                        ColumnDef::new(MediaOnceDeliveries::EncryptionMode)
                            .string_len(24)
                            .not_null()
                            .default("plaintext"),
                    )
                    .add_column(
                        ColumnDef::new(MediaOnceDeliveries::ProtocolVersion)
                            .string_len(40)
                            .null(),
                    )
                    .add_column(
                        ColumnDef::new(MediaOnceDeliveries::SenderDeviceId)
                            .string_len(120)
                            .null(),
                    )
                    .add_column(
                        ColumnDef::new(MediaOnceDeliveries::RecipientDeviceId)
                            .string_len(120)
                            .null(),
                    )
                    .add_column(
                        ColumnDef::new(MediaOnceDeliveries::EncryptionNonce)
                            .string_len(120)
                            .null(),
                    )
                    .add_column(
                        ColumnDef::new(MediaOnceDeliveries::EncryptionMac)
                            .string_len(120)
                            .null(),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(MediaOnceDeliveries::Table)
                    .drop_column(MediaOnceDeliveries::EncryptionMac)
                    .drop_column(MediaOnceDeliveries::EncryptionNonce)
                    .drop_column(MediaOnceDeliveries::RecipientDeviceId)
                    .drop_column(MediaOnceDeliveries::SenderDeviceId)
                    .drop_column(MediaOnceDeliveries::ProtocolVersion)
                    .drop_column(MediaOnceDeliveries::EncryptionMode)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }
}

#[derive(DeriveIden)]
enum MediaOnceDeliveries {
    Table,
    EncryptionMode,
    ProtocolVersion,
    SenderDeviceId,
    RecipientDeviceId,
    EncryptionNonce,
    EncryptionMac,
}
