# The Bit and Bond E2EE Architecture v1

Last updated: 2026-03-09

This document defines the recommended end-to-end encryption direction for
`The Bit and Bond`.

It is intentionally a design and rollout spec, not an implementation claim.
Do not ship partial cryptography without first satisfying the constraints in
this file.

Use this document together with
[product_revamp_blueprint.md](/Users/ivesliu/Documents/chen-leveling/docs/product_revamp_blueprint.md).

## 1. Core Decision

Yes, `The Bit and Bond` can support end-to-end encryption for messages and
photos.

However, E2EE should not be applied to every feature in the same way.

Recommended scope:

- `DM`:
  yes, this is the best first place for real E2EE
- `Private photo attachments inside DM`:
  yes, also a strong fit for E2EE
- `Habit proof photos`:
  possible, but only if the reviewer is the explicit decryption recipient
- `Family or group rooms`:
  possible later, but materially more complex
- `Photo Dump / share-to-social surfaces`:
  not full E2EE by default, because the product goal there is selective sharing

## 2. Product Principle

The product should distinguish between:

- `private communication`
- `review-only communication`
- `shared family content`
- `socially shared content`

Those are not the same privacy class.

The app should not present all content surfaces as equally encrypted when their
access patterns are different.

## 3. Security Goals

For E2EE surfaces, the goals are:

1. The server stores ciphertext, not readable plaintext.
2. Only intended participants can decrypt the content.
3. Message and attachment integrity is verifiable.
4. Device loss and device change are survivable through a defined recovery
   model.
5. Encryption design remains compatible with mobile performance constraints.

## 4. Non-Goals For v1

These should not block the first E2EE release:

- group E2EE with arbitrary room membership changes
- cross-platform web parity on day one
- perfect metadata hiding
- searchable encrypted history on the server
- public or semi-public photo dump encryption

## 5. Recommended Scope For v1

E2EE v1 should cover only:

1. 1:1 DM text messages
2. 1:1 DM photo attachments
3. optional 1:1 habit-proof photos when a friend is the designated reviewer

Do not start with:

- family-wide group threads
- voice-room E2EE
- all habit flows
- all photo dump sharing

## 6. Threat Model

E2EE v1 is designed to protect against:

- server-side plaintext access
- accidental admin or operator visibility into private DM content
- database leaks that expose stored messages or photos
- transport interception beyond TLS assumptions

E2EE v1 does not fully hide:

- who talks to whom
- when messages are sent
- approximate attachment sizes
- room or thread existence

This is acceptable for v1.

## 7. Recommended Crypto Direction

Do not invent custom cryptography.

Recommended approach:

- use audited primitives and audited libraries
- prefer a Signal-style design for 1:1 messaging if library support is
  production-acceptable
- if a full Signal-compatible path is not immediately feasible, use a narrower
  v1 design with clear limitations and no false marketing claims

Recommended primitive set:

- identity signing keys: `Ed25519`
- key agreement keys: `X25519`
- symmetric encryption: `XChaCha20-Poly1305`
- random values: CSPRNG from platform secure primitives

Recommended implementation note:

- use a mature `libsodium`-backed path where possible instead of assembling raw
  primitives by hand

## 8. Key Model

### 8.1 Identity And Device Keys

Each user should have:

- one account identity record
- one or more device key bundles

Each device key bundle should contain:

- device id
- public signing key
- public encryption key
- creation timestamp
- revocation state

Private keys must never leave the device unencrypted.

### 8.2 Device Storage

On iOS:

- store private key material using Keychain-backed secure storage

On Android:

- store private key material using Android Keystore-backed secure storage

Do not store raw long-term private keys in plain app storage.

## 9. 1:1 DM Message Flow

Recommended v1 logical flow:

1. sender resolves recipient device bundle
2. sender derives or updates the thread/session key material
3. sender encrypts message on-device
4. sender uploads only:
   - ciphertext
   - encrypted message envelope
   - delivery metadata required for routing
5. recipient downloads envelope
6. recipient decrypts locally

Server responsibilities:

- route encrypted payloads
- persist envelopes
- handle delivery state
- never inspect plaintext

## 10. Photo Attachment Flow

Photos should not be encrypted with the same direct message payload blob.

Recommended flow:

1. generate a random file key per attachment
2. encrypt the photo locally with that random file key
3. optionally create a separately encrypted thumbnail
4. upload ciphertext blob to storage
5. encrypt the file key into the DM message envelope
6. recipient downloads ciphertext blob and decrypts locally

The storage layer should only ever receive:

- encrypted photo bytes
- encrypted thumbnail bytes, if thumbnails are used
- opaque attachment ids

The storage layer should not receive readable thumbnails by default.

## 11. Habit Proof Photos

Habit proof photos are privacy-sensitive but are not equivalent to DM media.

Recommended rule:

- if the proof is submitted to exactly one reviewer, it may use the same E2EE
  attachment model as DM attachments
- if the proof is visible to multiple reviewers or family admins, treat it as
  reviewer-scoped encrypted content, not pure DM content

Do not mix habit proof encryption rules with public memory-sharing rules.

## 12. Photo Dump Privacy Model

Photo Dump should support multiple privacy modes:

1. `Private`
   only visible to the owner
2. `Direct share`
   visible only to explicitly chosen recipients
3. `Family`
   visible to family members
4. `Friends`
   visible to selected friends
5. `Public/social export`
   intentionally shareable outside the app

Only the first two are natural fits for strict E2EE in v1.

`Family` and `Friends` can be encrypted later, but membership churn makes them a
higher-complexity phase.

## 13. Recovery And Multi-Device

This is the hardest product problem and must be designed up front.

Recommended v1 constraint:

- ship E2EE first for one primary mobile device per account
- make secondary-device support a separate phase

Recommended recovery options:

1. device-to-device transfer with QR or secure pairing
2. recovery phrase
3. encrypted key backup protected by a user-controlled secret

Do not rely on server-stored plaintext recovery material.

## 14. UX Requirements

The product must be explicit about which surfaces are encrypted.

Recommended UX rules:

- show a clear `private / encrypted` state inside DM threads
- do not label social or family-shared surfaces as fully end-to-end encrypted
  unless they actually are
- for encrypted photos, make it clear that previews may take time to decrypt
- for recovery-sensitive actions, warn users before device reset or logout

## 15. Backend Changes Required

Backend support for E2EE v1 will require:

- device key registration endpoints
- key bundle lookup endpoints
- encrypted envelope storage for DM
- attachment metadata records that reference encrypted blobs
- delivery receipts without plaintext access
- device revocation support

The current DM backend should be treated as plaintext transport and persistence.
It should not be advertised as encrypted until the full E2EE path exists.

## 16. Client Changes Required

Client work for E2EE v1 will require:

- secure key generation and storage
- key registration during device setup
- on-device message encryption/decryption
- on-device media encryption/decryption
- attachment upload/download handling for ciphertext blobs
- recovery and device migration UX
- explicit encrypted-thread UI states

## 17. Tradeoffs

If E2EE is adopted:

- server-side search becomes limited or unavailable
- content moderation becomes much harder for private surfaces
- push notification previews should avoid plaintext by default
- debugging production issues becomes harder
- attachment processing pipelines become more complex

These are expected tradeoffs, not bugs.

## 18. Recommended Rollout Phases

### Phase A: Prepare The Model

- define privacy classes across DM, habits, family, and photo dump
- add device identity records
- add attachment metadata model
- avoid expanding plaintext DM assumptions further

### Phase B: E2EE For 1:1 DM Text

- one-device-first release
- encrypted DM envelopes
- basic key registration and revocation

### Phase C: E2EE For 1:1 DM Photos

- encrypted photo blobs
- encrypted thumbnails or no server thumbnails
- attachment send/download UX

### Phase D: Reviewer-Scoped Habit Proof Photos

- only for flows with explicit reviewer access
- not for broad family-shared or public surfaces

### Phase E: Multi-Device And Expanded Sharing

- secondary devices
- family/group encryption
- richer encrypted media sharing

## 19. Engineering Recommendation

Do not implement ad hoc cryptography directly inside the current Flutter and
Rust code paths without a protocol review.

Recommended next step:

1. finalize privacy classes per feature
2. choose the crypto library stack
3. design the device key lifecycle
4. implement `DM text E2EE` first
5. then add `DM photo E2EE`

## 20. Current Project Status

As of 2026-03-09:

- DM exists and is functional
- DM is not yet end-to-end encrypted
- photo dump is not yet a real media pipeline
- habit proof exists conceptually, but encrypted proof media is not yet
  implemented

This document should be treated as the safe architecture reference before
shipping any E2EE claim in the product.
