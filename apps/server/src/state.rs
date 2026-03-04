use sea_orm::DatabaseConnection;

use crate::jwt::JwtService;
use crate::presence::PresenceHub;

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
    pub jwt: JwtService,
    pub presence: PresenceHub,
}

impl AppState {
    pub fn new(db: DatabaseConnection, jwt: JwtService) -> Self {
        Self {
            db,
            jwt,
            presence: PresenceHub::new(),
        }
    }
}
