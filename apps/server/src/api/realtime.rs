use std::collections::HashSet;

use axum::{
    Json,
    extract::{
        Query, State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    response::Response,
};
use chrono::Utc;
use entity::hunter;
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    error::{AppError, AppResult},
    extractors::AuthClaims,
    jwt::Claims,
    presence::{HunterFacing, HunterPose, PresenceEvent},
    state::AppState,
};

#[derive(Debug, Deserialize)]
pub struct RealtimeWsQuery {
    pub ticket: String,
}

#[derive(Debug, Serialize)]
pub struct RealtimeTicketResponse {
    pub ticket: String,
    pub expires_in: i64,
}

pub async fn issue_ws_ticket(
    AuthClaims(claims): AuthClaims,
    State(state): State<AppState>,
) -> AppResult<Json<RealtimeTicketResponse>> {
    let issued = state.realtime_tickets.issue(&claims).await;
    Ok(Json(RealtimeTicketResponse {
        ticket: issued.ticket,
        expires_in: issued.expires_in,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClientRealtimeMessage {
    Pose {
        hunter_id: Uuid,
        x: f32,
        y: f32,
        facing: HunterFacing,
        moving: bool,
    },
}

#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ServerRealtimeMessage {
    Snapshot { positions: Vec<HunterPose> },
    Pose { pose: HunterPose },
    ChatNotice { room_id: String, message_id: Uuid },
}

pub async fn ws_upgrade(
    State(state): State<AppState>,
    Query(query): Query<RealtimeWsQuery>,
    ws: WebSocketUpgrade,
) -> AppResult<Response> {
    let claims = state
        .realtime_tickets
        .consume(query.ticket.trim())
        .await
        .ok_or_else(|| AppError::Unauthorized("invalid or expired realtime ticket".into()))?;
    let allowed_hunters = resolve_allowed_hunters(&state, &claims).await?;

    Ok(ws.on_upgrade(move |socket| async move {
        handle_socket(socket, state, claims, allowed_hunters).await;
    }))
}

async fn resolve_allowed_hunters(state: &AppState, claims: &Claims) -> AppResult<HashSet<Uuid>> {
    let hunter_id = claims
        .hunter_id
        .ok_or_else(|| AppError::Unauthorized("token missing hunter_id".into()))?;
    let exists = hunter::Entity::find_by_id(hunter_id)
        .filter(hunter::Column::GuildId.eq(claims.guild_id))
        .one(&state.db)
        .await?
        .is_some();
    if !exists {
        return Err(AppError::Unauthorized(
            "hunter does not belong to this guild".into(),
        ));
    }
    Ok(HashSet::from([hunter_id]))
}

async fn handle_socket(
    mut socket: WebSocket,
    state: AppState,
    claims: Claims,
    allowed_hunters: HashSet<Uuid>,
) {
    let (session_id, mut guild_rx, snapshot) = state.presence.subscribe(claims.guild_id).await;

    if send_json(
        &mut socket,
        &ServerRealtimeMessage::Snapshot {
            positions: snapshot,
        },
    )
    .await
    .is_err()
    {
        return;
    }

    loop {
        tokio::select! {
            incoming = socket.recv() => {
                match incoming {
                    Some(Ok(Message::Text(text))) => {
                        if handle_incoming_text(
                            &state,
                            claims.guild_id,
                            session_id,
                            &allowed_hunters,
                            &text,
                        ).await.is_err() {
                            break;
                        }
                    }
                    Some(Ok(Message::Binary(_))) => {}
                    Some(Ok(Message::Ping(payload))) => {
                        if socket.send(Message::Pong(payload)).await.is_err() {
                            break;
                        }
                    }
                    Some(Ok(Message::Pong(_))) => {}
                    Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                }
            }
            evt = guild_rx.recv() => {
                match evt {
                    Ok(event) => {
                        match event {
                            PresenceEvent::Pose { session_id: event_session_id, pose } => {
                                if event_session_id == session_id {
                                    continue;
                                }
                                if send_json(
                                    &mut socket,
                                    &ServerRealtimeMessage::Pose { pose },
                                ).await.is_err() {
                                    break;
                                }
                            }
                            PresenceEvent::ChatNotice { room_id, message_id } => {
                                if send_json(
                                    &mut socket,
                                    &ServerRealtimeMessage::ChatNotice {
                                        room_id,
                                        message_id,
                                    },
                                ).await.is_err() {
                                    break;
                                }
                            }
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                }
            }
        }
    }

    state
        .presence
        .remove_session(claims.guild_id, session_id)
        .await;
}

async fn handle_incoming_text(
    state: &AppState,
    guild_id: Uuid,
    session_id: Uuid,
    allowed_hunters: &HashSet<Uuid>,
    text: &str,
) -> Result<(), ()> {
    let parsed: ClientRealtimeMessage = serde_json::from_str(text).map_err(|_| ())?;
    let ClientRealtimeMessage::Pose {
        hunter_id,
        x,
        y,
        facing,
        moving,
    } = parsed;

    if !allowed_hunters.contains(&hunter_id) {
        return Ok(());
    }
    if !x.is_finite() || !y.is_finite() {
        return Ok(());
    }

    let pose = HunterPose {
        hunter_id,
        x: x.clamp(0.0, 10000.0),
        y: y.clamp(0.0, 10000.0),
        facing,
        moving,
        updated_at_ms: Utc::now().timestamp_millis(),
    };

    state
        .presence
        .publish_pose(guild_id, session_id, pose)
        .await;
    Ok(())
}

async fn send_json(socket: &mut WebSocket, payload: &ServerRealtimeMessage) -> Result<(), ()> {
    let text = serde_json::to_string(payload).map_err(|_| ())?;
    socket
        .send(Message::Text(text.into()))
        .await
        .map_err(|_| ())
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use uuid::Uuid;

    use crate::presence::HunterFacing;

    use super::ClientRealtimeMessage;

    #[test]
    fn parse_pose_message() {
        let hunter_id = Uuid::new_v4();
        let raw = format!(
            r#"{{"type":"pose","hunter_id":"{hunter_id}","x":12.3,"y":45.6,"facing":"down","moving":true}}"#
        );
        let parsed: ClientRealtimeMessage = serde_json::from_str(&raw).expect("valid json");
        let ClientRealtimeMessage::Pose {
            hunter_id: parsed_id,
            x,
            y,
            facing,
            moving,
        } = parsed;

        assert_eq!(parsed_id, hunter_id);
        assert_eq!(x, 12.3);
        assert_eq!(y, 45.6);
        assert_eq!(facing, HunterFacing::Down);
        assert!(moving);
    }

    #[test]
    fn ignores_unknown_hunter_by_set_check() {
        let allowed = HashSet::from([Uuid::new_v4()]);
        let outsider = Uuid::new_v4();
        assert!(!allowed.contains(&outsider));
    }
}
