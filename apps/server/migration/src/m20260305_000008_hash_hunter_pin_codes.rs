use argon2::{
    Argon2,
    password_hash::{PasswordHasher, SaltString, rand_core::OsRng},
};
use sea_orm::{ConnectionTrait, Statement, prelude::Uuid};
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
                    .modify_column(ColumnDef::new(Hunters::PinCode).string_len(255).not_null())
                    .to_owned(),
            )
            .await?;

        let backend = manager.get_database_backend();
        let rows = manager
            .get_connection()
            .query_all(Statement::from_string(
                backend,
                "SELECT id, pin_code FROM hunters".to_string(),
            ))
            .await?;

        for row in rows {
            let hunter_id: Uuid = row.try_get("", "id")?;
            let pin_code: String = row.try_get("", "pin_code")?;
            if pin_code.starts_with("$argon2") {
                continue;
            }
            let hash = hash_pin_code(&pin_code)?;
            manager
                .get_connection()
                .execute(Statement::from_sql_and_values(
                    backend,
                    "UPDATE hunters SET pin_code = $1 WHERE id = $2",
                    vec![hash.into(), hunter_id.into()],
                ))
                .await?;
        }

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .modify_column(ColumnDef::new(Hunters::PinCode).string_len(255).not_null())
                    .to_owned(),
            )
            .await
    }
}

fn hash_pin_code(pin_code: &str) -> Result<String, DbErr> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(pin_code.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| DbErr::Migration("failed to hash hunter pin_code".into()))
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    PinCode,
}
