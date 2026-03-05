# Server (Axum + SeaORM)

## Environment

- `DATABASE_URL` default: `postgres://chen:chen@127.0.0.1:5432/chen_leveling`
- `BIND_ADDR` default: `127.0.0.1:18080`
- `ALLOWED_ORIGIN` default: `*` (for local dev; set explicit origins in production)
- `AUTO_MIGRATE` default: `true`
- `REDIS_URL` optional: enable multi-node realtime presence pub/sub

## Data model

- `users`: guild master login credentials
- `guilds`: family scope container (owned by user)
- `hunters`: child player profile inside a guild
- `quests`: guild scoped tasks with lifecycle status
  - `stat_category`: `STR | INT | AGI | CHA | VIT | NONE`

## API flow

1. 玩家註冊（建立玩家 + 個人公會）(`POST /api/v1/auth/register`)
2. 玩家登入（`account` 可為 `player_id` 或 `email`）(`POST /api/v1/auth/login`)
3. 取得當前登入身份 (`GET /api/v1/auth/me`)
4. 公會長管理獵人 (`POST/GET /api/v1/hunters`, `PATCH /api/v1/hunters/{id}/pin`)
5. 公會任務流程 (`POST/GET /api/v1/quests`, `POST /api/v1/quests/{id}/submit`, `POST /api/v1/quests/{id}/review`)

## Auth model

- Protected endpoints use `Authorization: Bearer <jwt>`.
- Role checks:
  - `master`: manage hunters and guild resources.
  - `member`: limited gameplay permissions.
- 密碼與 PIN 皆以 Argon2 雜湊儲存。

## Unified Auth cURL examples

### 1) Register player (auto-login response)

```bash
curl -i -X POST http://127.0.0.1:18080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{
    "account": "chen001",
    "secret": "1234",
    "display_name": "阿諶"
  }'
```

Example success payload:

```json
{
  "access_token": "<jwt>",
  "token_type": "Bearer",
  "expires_in": 28800,
  "role": "player",
  "guild_role": "master",
  "guild_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "hunter_id": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "player_id": "chen001",
  "display_name": "阿諶"
}
```

### 2) Login player (player_id + pin)

```bash
curl -i -X POST http://127.0.0.1:18080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{
    "account": "chen001",
    "secret": "1234"
  }'
```
