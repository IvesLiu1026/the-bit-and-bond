# Architecture Notes

## Monorepo strategy

`The Bit and Bond` uses a single repository to keep API contract, data model, backend logic, and client integration in lockstep.

## Boundaries

- `apps/server`: authoritative business logic and settlement
- `apps/client_flutter`: player-side interaction, rendering, and local state
- `packages/api-spec`: REST contract that both sides align to

## State authority

- Client can stage interactions, but quest approval and progression rewards are server-authoritative.
- `hunter_reward_ledger` is the append-only source of truth for XP and coin changes.
- `hunters` stores the current player snapshot used for fast reads.

## Transport

- Baseline: REST for auth, quests, DM, media, shop, inventory, telemetry, and voice token issuance.
- Realtime presence uses `POST /api/v1/realtime/ticket` followed by `GET /api/v1/realtime/ws?ticket=...`.
- OpenAPI lives in `packages/api-spec/openapi.yaml`, and CI verifies every `/api/v1/*` router path is documented there.
