use migration::Migrator;
use sea_orm_migration::cli;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    cli::run_cli(Migrator).await;
}
