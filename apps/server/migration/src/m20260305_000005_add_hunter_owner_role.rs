use sea_orm::{ConnectionTrait, Statement, Value, prelude::Uuid};
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        let backend = manager.get_database_backend();

        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .add_column(ColumnDef::new(Hunters::UserId).uuid().null())
                    .to_owned(),
            )
            .await?;
        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .add_column(ColumnDef::new(Hunters::GuildRole).string_len(16).null())
                    .to_owned(),
            )
            .await?;

        manager
            .get_connection()
            .execute(Statement::from_string(
                backend,
                r#"
                UPDATE hunters
                SET guild_role = 'member'
                WHERE guild_role IS NULL OR guild_role = '';
                "#
                .to_string(),
            ))
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_hunters_user_id_unique")
                    .table(Hunters::Table)
                    .col(Hunters::UserId)
                    .unique()
                    .to_owned(),
            )
            .await?;
        manager
            .create_index(
                Index::create()
                    .name("idx_hunters_guild_role")
                    .table(Hunters::Table)
                    .col(Hunters::GuildId)
                    .col(Hunters::GuildRole)
                    .to_owned(),
            )
            .await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .add_foreign_key(
                        TableForeignKey::new()
                            .name("fk_hunters_user_id")
                            .from_tbl(Hunters::Table)
                            .from_col(Hunters::UserId)
                            .to_tbl(Users::Table)
                            .to_col(Users::Id)
                            .on_update(ForeignKeyAction::Cascade)
                            .on_delete(ForeignKeyAction::SetNull),
                    )
                    .to_owned(),
            )
            .await?;

        backfill_owner_hunters(manager).await?;

        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .modify_column(
                        ColumnDef::new(Hunters::GuildRole)
                            .string_len(16)
                            .not_null()
                            .default("member"),
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
                    .table(Hunters::Table)
                    .drop_foreign_key(Alias::new("fk_hunters_user_id"))
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_hunters_guild_role")
                    .table(Hunters::Table)
                    .to_owned(),
            )
            .await?;
        manager
            .drop_index(
                Index::drop()
                    .name("idx_hunters_user_id_unique")
                    .table(Hunters::Table)
                    .to_owned(),
            )
            .await?;
        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .drop_column(Hunters::GuildRole)
                    .to_owned(),
            )
            .await?;
        manager
            .alter_table(
                Table::alter()
                    .table(Hunters::Table)
                    .drop_column(Hunters::UserId)
                    .to_owned(),
            )
            .await?;
        Ok(())
    }
}

async fn backfill_owner_hunters(manager: &SchemaManager<'_>) -> Result<(), DbErr> {
    let backend = manager.get_database_backend();
    let conn = manager.get_connection();
    let guild_rows = conn
        .query_all(Statement::from_string(
            backend,
            "SELECT id, owner_id FROM guilds ORDER BY id".to_string(),
        ))
        .await?;

    for guild_row in guild_rows {
        let guild_id: Uuid = guild_row.try_get("", "id")?;
        let owner_id: Uuid = guild_row.try_get("", "owner_id")?;

        if let Some(owner_hunter_id) = find_owner_hunter(conn, backend, guild_id, owner_id).await? {
            conn.execute(Statement::from_sql_and_values(
                backend,
                r#"
                UPDATE hunters
                SET user_id = $1, guild_role = 'master'
                WHERE id = $2
                "#,
                vec![
                    Value::Uuid(Some(Box::new(owner_id))),
                    Value::Uuid(Some(Box::new(owner_hunter_id))),
                ],
            ))
            .await?;
            continue;
        }

        let hunter_id = Uuid::new_v4();
        let player_id = pick_unique_owner_player_id(conn, backend, owner_id).await?;
        let pin_code = pick_available_pin(conn, backend, guild_id).await?;

        conn.execute(Statement::from_sql_and_values(
            backend,
            r#"
            INSERT INTO hunters
              (id, guild_id, user_id, player_id, name, avatar_type, level, xp, coins, pin_code, guild_role)
            VALUES
              ($1, $2, $3, $4, $5, $6, 1, 0, 0, $7, 'master')
            "#,
            vec![
                hunter_id.into(),
                guild_id.into(),
                owner_id.into(),
                player_id.into(),
                "公會長".to_string().into(),
                "master".to_string().into(),
                pin_code.into(),
            ],
        ))
        .await?;
    }

    Ok(())
}

async fn find_owner_hunter<C>(
    conn: &C,
    backend: sea_orm::DatabaseBackend,
    guild_id: Uuid,
    owner_id: Uuid,
) -> Result<Option<Uuid>, DbErr>
where
    C: ConnectionTrait,
{
    let row = conn
        .query_one(Statement::from_sql_and_values(
            backend,
            r#"
            SELECT id
            FROM hunters
            WHERE guild_id = $1 AND (user_id = $2 OR guild_role = 'master')
            ORDER BY CASE WHEN user_id = $2 THEN 0 ELSE 1 END, id
            LIMIT 1
            "#,
            [guild_id.into(), owner_id.into()],
        ))
        .await?;

    match row {
        Some(row) => {
            let id: Uuid = row.try_get("", "id")?;
            Ok(Some(id))
        }
        None => Ok(None),
    }
}

async fn pick_unique_owner_player_id<C>(
    conn: &C,
    backend: sea_orm::DatabaseBackend,
    owner_id: Uuid,
) -> Result<String, DbErr>
where
    C: ConnectionTrait,
{
    let base = format!("gm_{}", &owner_id.simple().to_string()[..8]);
    for attempt in 0..64 {
        let candidate = if attempt == 0 {
            base.clone()
        } else {
            format!("{base}_{:02}", attempt)
        };
        let exists = conn
            .query_one(Statement::from_sql_and_values(
                backend,
                "SELECT 1 AS exists_flag FROM hunters WHERE player_id = $1 LIMIT 1",
                [candidate.clone().into()],
            ))
            .await?
            .is_some();
        if !exists {
            return Ok(candidate);
        }
    }
    Ok(format!("gm_{}", &Uuid::new_v4().simple().to_string()[..10]))
}

async fn pick_available_pin<C>(
    conn: &C,
    backend: sea_orm::DatabaseBackend,
    guild_id: Uuid,
) -> Result<String, DbErr>
where
    C: ConnectionTrait,
{
    let pin_rows = conn
        .query_all(Statement::from_sql_and_values(
            backend,
            "SELECT pin_code FROM hunters WHERE guild_id = $1",
            [guild_id.into()],
        ))
        .await?;
    let mut occupied = std::collections::HashSet::with_capacity(pin_rows.len());
    for row in pin_rows {
        let pin: String = row.try_get("", "pin_code")?;
        occupied.insert(pin);
    }
    for pin in 0..10_000 {
        let candidate = format!("{pin:04}");
        if !occupied.contains(&candidate) {
            return Ok(candidate);
        }
    }
    Ok("9999".to_string())
}

#[derive(DeriveIden)]
enum Users {
    Table,
    Id,
}

#[derive(DeriveIden)]
enum Hunters {
    Table,
    GuildId,
    UserId,
    GuildRole,
}
