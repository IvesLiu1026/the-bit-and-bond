use sea_orm::DatabaseConnection;

use crate::auth_throttle::AuthThrottle;
use crate::jwt::JwtService;
use crate::presence::PresenceHub;
use crate::realtime_ticket::RealtimeTicketStore;

#[derive(Clone)]
pub struct LiveKitConfig {
    pub url: String,
    pub api_key: String,
    pub api_secret: String,
    pub token_ttl_seconds: i64,
    pub chat_topic: String,
}

#[derive(Clone)]
pub struct FirebaseAuthConfig {
    pub project_id: String,
}

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
    pub jwt: JwtService,
    pub presence: PresenceHub,
    pub realtime_tickets: RealtimeTicketStore,
    pub auth_throttle: AuthThrottle,
    pub livekit: Option<LiveKitConfig>,
    pub firebase_auth: Option<FirebaseAuthConfig>,
}

impl AppState {
    #[allow(dead_code)]
    pub fn new(db: DatabaseConnection, jwt: JwtService) -> Self {
        Self::with_services(db, jwt, PresenceHub::new(), None, None)
    }

    #[allow(dead_code)]
    pub fn with_presence_and_livekit(
        db: DatabaseConnection,
        jwt: JwtService,
        presence: PresenceHub,
        livekit: Option<LiveKitConfig>,
    ) -> Self {
        Self::with_services(db, jwt, presence, livekit, None)
    }

    pub fn with_services(
        db: DatabaseConnection,
        jwt: JwtService,
        presence: PresenceHub,
        livekit: Option<LiveKitConfig>,
        firebase_auth: Option<FirebaseAuthConfig>,
    ) -> Self {
        let realtime_tickets = RealtimeTicketStore::new(30);
        let auth_throttle = AuthThrottle::new();
        Self {
            db,
            jwt,
            presence,
            realtime_tickets,
            auth_throttle,
            livekit,
            firebase_auth,
        }
    }
}
