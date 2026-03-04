# Server (Axum + SeaORM)

## Environment

- `DATABASE_URL` default: `postgres://chen:chen@127.0.0.1:5432/chen_leveling`
- `BIND_ADDR` default: `127.0.0.1:18080`
- `ALLOWED_ORIGIN` default: `*` (for local dev; set explicit origins in production)
- `AUTO_MIGRATE` default: `true`

## Data model

- `users`: guild master login credentials
- `guilds`: family scope container (owned by user)
- `hunters`: child player profile inside a guild
- `quests`: guild scoped tasks with lifecycle status

## API flow

1. Guild master registers (`POST /api/v1/auth/master/register`)
2. Guild master logs in (`POST /api/v1/auth/master/login`)
3. Guild master manages hunters (`POST/GET /api/v1/hunters`, `PATCH /api/v1/hunters/{id}/pin`)
4. Guild master creates quests (`POST /api/v1/quests`)
5. Hunter/master list quests in same guild (`GET /api/v1/quests`)
6. Hunter submits quest (`POST /api/v1/quests/{id}/submit`)
7. Guild master reviews quest (`POST /api/v1/quests/{id}/review`)
8. Hunter logs in (`POST /api/v1/auth/hunter/login`)

## Auth model

- Protected endpoints use `Authorization: Bearer <jwt>`.
- Role checks:
  - `guild_master`: manage hunters and guild resources.
  - `hunter`: limited gameplay permissions.

## Guild Auth cURL examples

### 1) Register guild master (auto-login response)

```bash
curl -i -X POST http://127.0.0.1:18080/api/v1/auth/master/register \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "guildmaster@example.com",
    "password": "Passw0rd!",
    "guild_name": "諶家專屬公會"
  }'
```

Example success payload:

```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 28800,
  "role": "guild_master",
  "guild_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "invite_code": "ABCD23"
}
```

### 2) Login guild master

```bash
curl -i -X POST http://127.0.0.1:18080/api/v1/auth/master/login \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "guildmaster@example.com",
    "password": "Passw0rd!"
  }'
```
