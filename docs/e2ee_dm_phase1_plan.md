# The Bit and Bond E2EE DM Phase 1 Plan

Last updated: 2026-03-09

This document translates
[e2ee_architecture_v1.md](/Users/ivesliu/Documents/chen-leveling/docs/e2ee_architecture_v1.md)
into a concrete first implementation phase for direct messages.

Phase 1 is intentionally narrow:

- encrypted 1:1 DM text only
- single-primary-device-first rollout
- no encrypted media yet
- no family/group room encryption yet

## 1. Phase 1 Goal

Ship a version of DM where:

- the server stores encrypted message payloads
- only the sender and recipient device can decrypt the text
- key registration and lookup are supported
- the app can clearly indicate whether a DM thread is encrypted

Do not include photos in this phase.

## 2. Product Scope

Phase 1 applies only to:

- `DM` thread list
- `DM` message history
- `DM` send flow

It does not apply to:

- group chat
- family-wide rooms
- habit proof uploads
- photo dump
- push notification plaintext previews

## 3. Delivery Strategy

Recommended release order:

1. backend and data model preparation
2. client-side device key bootstrap
3. encrypted thread capability flag
4. encrypted send and receive
5. staged rollout for internal/demo accounts first

## 4. Backend Data Model

### 4.1 New Tables

Recommended tables:

#### `dm_device_keys`

Stores one row per registered device.

Suggested columns:

- `id`
- `hunter_id`
- `device_id`
- `device_label`
- `signing_public_key`
- `encryption_public_key`
- `created_at`
- `last_seen_at`
- `revoked_at`

#### `dm_encrypted_messages`

Stores encrypted envelopes rather than plaintext messages.

Suggested columns:

- `id`
- `conversation_key`
- `sender_hunter_id`
- `recipient_hunter_id`
- `sender_device_id`
- `recipient_device_id`
- `client_message_id`
- `ciphertext`
- `nonce`
- `protocol_version`
- `sent_at`
- `sent_at_ms`

#### `dm_conversation_capabilities`

Marks whether a 1:1 thread is plaintext, mixed, or encrypted.

Suggested columns:

- `conversation_key`
- `left_hunter_id`
- `right_hunter_id`
- `mode`
- `upgraded_at`
- `last_handshake_at`

### 4.2 Existing Plaintext DM Table

Do not silently reuse the existing plaintext message table for encrypted
payloads if it makes code paths ambiguous.

Preferred approach:

- keep current plaintext DM flow intact during migration
- add encrypted message storage in parallel
- migrate thread-by-thread when both sides are capable

## 5. API Surface

### 5.1 Device Key Endpoints

Recommended endpoints:

- `POST /api/v1/direct-messages/device-keys/register`
- `GET /api/v1/direct-messages/device-keys/:hunter_id`
- `POST /api/v1/direct-messages/device-keys/revoke`

### 5.2 Conversation Capability Endpoints

Recommended endpoints:

- `GET /api/v1/direct-messages/threads`
  return thread metadata plus `encryption_mode`
- `POST /api/v1/direct-messages/threads/:counterpart_id/upgrade`

### 5.3 Encrypted Message Endpoints

Recommended endpoints:

- `POST /api/v1/direct-messages/encrypted`
- `GET /api/v1/direct-messages/:counterpart_id/encrypted-history`

The encrypted history endpoint should return envelopes and metadata only.

## 6. Client Key Lifecycle

### 6.1 First Launch After Login

On first authenticated device setup:

1. generate signing keypair
2. generate encryption keypair
3. store private keys in secure storage
4. register public keys with backend
5. persist a local `device_id`

### 6.2 Existing Users

For existing demo or live accounts:

- allow the app to continue plaintext DM until device keys are registered
- then expose an `encrypted available` state for eligible 1:1 threads

### 6.3 Logout

Do not delete device keys on every logout by default.

Instead:

- clear auth tokens
- keep device identity locally unless the user explicitly resets secure data

## 7. Thread Upgrade Flow

Recommended upgrade flow:

1. both users have registered device keys
2. sender opens a DM thread
3. app checks recipient capability
4. if both sides are capable, thread can be upgraded to encrypted mode
5. once upgraded, new text messages use encrypted envelopes

Plaintext history should stay plaintext unless a separate migration plan is
introduced later.

## 8. UI Requirements

The DM inbox and chat page should expose encryption state clearly.

Recommended indicators:

- thread chip: `Encrypted` / `Not Encrypted`
- chat header subtitle:
  `Only people in this thread can read these messages`
- compose box:
  small lock icon when encryption is active

Do not show a lock icon for plaintext threads.

## 9. Push Notification Policy

For encrypted DM threads:

- push notifications should avoid plaintext previews by default
- preferred push text:
  `New encrypted message`

If the product later offers preview-on-device, it must be opt-in and handled
carefully.

## 10. Observability

Server logs for encrypted DM should include only:

- message id
- conversation key
- sender id
- recipient id
- payload size
- delivery status

Server logs must not include decrypted text.

## 11. Risks

Primary risks in phase 1:

- key loss and no recovery path
- multiple devices causing session inconsistency
- partially upgraded threads
- misleading UI that suggests content is encrypted when it is not

## 12. Recommended Implementation Checklist

### Backend

- add device key entity and migration
- add encrypted DM entity and migration
- add capability metadata
- add key registration and lookup endpoints
- add encrypted send/history endpoints

### Client

- generate and store device keys
- register device key bundle after login
- show thread encryption mode
- encrypt outgoing DM text
- decrypt incoming DM text

### Product

- add encrypted thread UI state
- define fallback behavior for unsupported peers
- define recovery-language copy before shipping

## 13. Definition Of Done For Phase 1

Phase 1 is done when:

1. two devices can exchange DM text without the server storing plaintext
2. encrypted and plaintext thread states are visually distinct
3. device key registration works reliably
4. logs and API payloads do not leak plaintext
5. the app does not claim photo encryption yet

## 14. Explicit Not-Yet-Done Items

These remain future work:

- encrypted photo attachments
- encrypted habit proof media
- family/group thread encryption
- multi-device sync and transfer UX
- secure key backup and recovery

This file should be used as the direct reference for implementation work after
the current DM UX cleanup.
