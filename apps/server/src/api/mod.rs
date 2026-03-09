mod chat;
mod direct_messages;
mod health;
mod hunters;
mod inventory;
mod quests;
mod realtime;
mod shop;
mod social;
mod voice;

use axum::Router;

use crate::{auth, state::AppState};

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/health", axum::routing::get(health::health))
        .route("/api/v1/health", axum::routing::get(health::health))
        .route(
            "/api/v1/auth/register",
            axum::routing::post(auth::unified_register),
        )
        .route(
            "/api/v1/auth/login",
            axum::routing::post(auth::unified_login),
        )
        .route(
            "/api/v1/auth/firebase",
            axum::routing::post(auth::firebase_login),
        )
        .route("/api/v1/auth/me", axum::routing::get(auth::me))
        .route(
            "/api/v1/hunters",
            axum::routing::post(hunters::create_hunter).get(hunters::list_hunters),
        )
        .route(
            "/api/v1/hunters/roster",
            axum::routing::get(hunters::list_guild_hunters),
        )
        .route("/api/v1/hunters/me", axum::routing::get(hunters::hunter_me))
        .route(
            "/api/v1/hunters/{hunter_id}/stats",
            axum::routing::get(hunters::hunter_stats),
        )
        .route(
            "/api/v1/hunters/{hunter_id}/pin",
            axum::routing::patch(hunters::reset_hunter_pin),
        )
        .route(
            "/api/v1/quests",
            axum::routing::post(quests::create_quest).get(quests::list_quests),
        )
        .route(
            "/api/v1/quests/{quest_id}/submit",
            axum::routing::post(quests::submit_quest),
        )
        .route(
            "/api/v1/quests/{quest_id}/proof-media",
            axum::routing::post(quests::upload_quest_proof_media),
        )
        .route(
            "/api/v1/quests/{quest_id}/review",
            axum::routing::post(quests::review_quest),
        )
        .route(
            "/api/v1/quests/proof-media/{media_id}/content",
            axum::routing::get(quests::get_quest_proof_media_content),
        )
        .route(
            "/api/v1/realtime/ticket",
            axum::routing::post(realtime::issue_ws_ticket),
        )
        .route(
            "/api/v1/realtime/ws",
            axum::routing::get(realtime::ws_upgrade),
        )
        .route(
            "/api/v1/shop/items",
            axum::routing::get(shop::list_shop_items).post(shop::create_shop_item),
        )
        .route(
            "/api/v1/shop/items/{item_id}",
            axum::routing::put(shop::update_shop_item).delete(shop::deactivate_shop_item),
        )
        .route(
            "/api/v1/shop/buy/{item_id}",
            axum::routing::post(shop::buy_item),
        )
        .route(
            "/api/v1/inventory",
            axum::routing::get(inventory::list_inventory),
        )
        .route(
            "/api/v1/inventory/use/{item_id}",
            axum::routing::post(inventory::use_inventory_item),
        )
        .route(
            "/api/v1/voice/token",
            axum::routing::post(voice::issue_voice_token),
        )
        .route(
            "/api/v1/chat/messages",
            axum::routing::post(chat::persist_chat_message),
        )
        .route(
            "/api/v1/chat/history",
            axum::routing::get(chat::list_chat_history),
        )
        .route(
            "/api/v1/direct-messages/device-keys/register",
            axum::routing::post(direct_messages::register_dm_device_key),
        )
        .route(
            "/api/v1/direct-messages/device-keys",
            axum::routing::get(direct_messages::list_dm_device_keys_batch),
        )
        .route(
            "/api/v1/direct-messages/device-keys/{hunter_id}",
            axum::routing::get(direct_messages::list_dm_device_keys),
        )
        .route(
            "/api/v1/direct-messages/device-keys/revoke",
            axum::routing::post(direct_messages::revoke_dm_device_key),
        )
        .route(
            "/api/v1/direct-messages/messages",
            axum::routing::post(direct_messages::persist_direct_message),
        )
        .route(
            "/api/v1/direct-messages/history",
            axum::routing::get(direct_messages::list_direct_message_history),
        )
        .route(
            "/api/v1/direct-messages/encrypted/messages",
            axum::routing::post(direct_messages::persist_encrypted_direct_message),
        )
        .route(
            "/api/v1/direct-messages/encrypted/history",
            axum::routing::get(direct_messages::list_encrypted_direct_message_history),
        )
        .route(
            "/api/v1/direct-messages/threads",
            axum::routing::get(direct_messages::list_direct_message_threads),
        )
        .route(
            "/api/v1/direct-messages/threads/{counterpart_hunter_id}/read",
            axum::routing::post(direct_messages::mark_direct_message_thread_read),
        )
        .route(
            "/api/v1/social/friends",
            axum::routing::get(social::list_friends).post(social::add_friend),
        )
        .route(
            "/api/v1/friends/request",
            axum::routing::post(social::request_friend),
        )
        .route(
            "/api/v1/friends/requests/incoming",
            axum::routing::get(social::list_incoming_friend_requests),
        )
        .route(
            "/api/v1/friends/requests/{request_id}/respond",
            axum::routing::post(social::respond_friend_request),
        )
        .route(
            "/api/v1/guilds/summon",
            axum::routing::post(social::summon_to_guild),
        )
        .route(
            "/api/v1/social/profile",
            axum::routing::get(social::social_profile).patch(social::update_social_profile),
        )
        .route(
            "/api/v1/social/guild/invites",
            axum::routing::get(social::list_my_guild_invites).post(social::invite_friend_to_guild),
        )
        .route(
            "/api/v1/social/guild/invites/{invite_id}/respond",
            axum::routing::post(social::respond_guild_invite),
        )
        .with_state(state)
}
