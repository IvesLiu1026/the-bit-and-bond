# Architecture Notes

## Monorepo strategy

`The Bit and Bond` uses a single repository to keep API contract, data model, backend logic, and client integration in lockstep.

## Boundaries

- `apps/server`: authoritative business logic and settlement
- `apps/client_flutter`: player-side interaction, rendering, and local state
- `packages/api-spec`: REST contract that both sides align to

## State authority

- Client can stage interactions, but quest approval and progression rewards are server-authoritative.
- `point_ledger` is append-only source of truth for rewards.
- `characters` is a snapshot table optimized for fast reads.

## Transport

- Baseline: REST for all core task/progression flows.
- Future optional add-on: WebSocket only for guardian approval push events.
