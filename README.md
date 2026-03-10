# The Bit and Bond

`The Bit and Bond` 是一個「RPG 公會生活」導向的任務與社交 App，採用 Monorepo 架構，包含：
- Rust 後端（Axum + SeaORM + PostgreSQL）
- Flutter 前端（Flame + Riverpod）
- 即時多人同步（WebSocket）

本文檔是給協作夥伴與新加入成員的架構總覽與開發手冊（以目前程式碼為準）。

## 1. 專案目標

- 讓玩家在酒館場景中移動、互動、接取任務
- 提供玩家註冊/登入、任務流程、社交關係與公會邀請
- 支援同公會多人即時位置同步
- 使用單一倉庫維護前後端與資料模型一致性

## 2. Monorepo 結構

```text
.
├── apps
│   ├── server                 # Rust API server
│   │   ├── src                # API / Auth / Realtime / Middleware
│   │   ├── entity             # SeaORM Entities
│   │   └── migration          # SeaORM migrations
│   └── client_flutter         # Flutter + Flame 客戶端
│       ├── lib
│       │   ├── app            # App entry / Auth gate
│       │   ├── core           # config/network/theme/auth model
│       │   ├── features       # auth/game/quests
│       │   └── state          # Riverpod state controllers
│       └── assets             # 字體、角色 sprite
├── infra                      # docker-compose / seed
├── docs                       # UI handoff / architecture notes
└── packages/api-spec          # OpenAPI 規格
```

## 3. 技術棧

### 後端
- Rust 2024
- Axum（REST + WebSocket）
- SeaORM + SeaORM Migration
- PostgreSQL
- JWT（`jsonwebtoken`）
- 密碼雜湊：Argon2

### 前端
- Flutter
- Flame（2D 場景、角色動畫、搖桿與碰撞）
- Riverpod（狀態管理）
- `flutter_secure_storage`（Session 儲存）
- `web_socket_channel`（多人同步）

## 4. 系統架構（高層）

```text
Flutter Client
  ├─ REST (/api/v1/auth, /hunters, /quests, /social...)
  └─ WS   (/api/v1/realtime/ws?token=...)
        ↓
Axum Server
  ├─ Auth + JWT + Extractors (角色/權限)
  ├─ Domain APIs (hunters/quests/social)
  ├─ Realtime Gateway (ws_upgrade)
  └─ PresenceHub (in-memory guild room broadcast)
        ↓
PostgreSQL (SeaORM)
```

## 5. 後端架構細節

### 5.1 模組分層

- `apps/server/src/main.rs`
  - 載入 `.env`
  - 建立 DB 連線與 JWT service
  - 啟動 migration（`AUTO_MIGRATE=true` 時）
  - 啟動 Axum server
- `apps/server/src/app.rs`
  - Router 組裝、CORS、HTTP trace layer
- `apps/server/src/api/*`
  - `health.rs`：健康檢查
  - `hunters.rs`：角色管理
  - `quests.rs`：任務狀態機
  - `social.rs`：好友/邀請/個人社交資訊
  - `realtime.rs`：WebSocket 連線與即時同步
- `apps/server/src/auth.rs`
  - 統一登入流程與舊路由相容流程
  - 註冊、登入、`/auth/me`
- `apps/server/src/jwt.rs`
  - Claims 結構與 token issue/decode
- `apps/server/src/extractors.rs`
  - `FromRequestParts` 權限抽取器
  - `AuthClaims` / `GuildMasterClaims` / `HunterClaims`
- `apps/server/src/presence.rs`
  - Guild 房間即時同步 hub（in-memory）

### 5.2 API 路由概覽（現況）

- Auth
  - `POST /api/v1/auth/register`（統一註冊）
  - `POST /api/v1/auth/login`（統一登入，支援玩家ID或Email）
  - `GET /api/v1/auth/me`
- Hunters
  - `POST/GET /api/v1/hunters`
  - `GET /api/v1/hunters/roster`
  - `GET /api/v1/hunters/me`
  - `PATCH /api/v1/hunters/{hunter_id}/pin`
- Quests
  - `POST/GET /api/v1/quests`
  - `POST /api/v1/quests/{quest_id}/submit`
  - `POST /api/v1/quests/{quest_id}/review`
- Social
  - `GET/POST /api/v1/social/friends`
  - `POST /api/v1/friends/request`
  - `GET /api/v1/friends/requests/incoming`
  - `POST /api/v1/friends/requests/{request_id}/respond`
  - `POST /api/v1/guilds/summon`
  - `GET/PATCH /api/v1/social/profile`
  - `GET/POST /api/v1/social/guild/invites`
  - `POST /api/v1/social/guild/invites/{invite_id}/respond`
- Realtime
  - `GET /api/v1/realtime/ws?token=<jwt>`

### 5.3 認證與權限模型

- JWT Claims（重點欄位）
  - `sub`
  - `guild_id`
  - `hunter_id`
  - `guild_role`（`master` / `member`）
  - `role`（固定為 `player`）
- Extractor 會在每次請求時再校驗 DB 身分，確保 token 與資料庫狀態一致
- 密碼（Email 登入）與 PIN（玩家登入）皆使用 Argon2 雜湊驗證

### 5.4 Realtime 多人同步（目前設計）

- 客戶端建立 WebSocket 連線並附上 JWT token
- 後端依 `guild_id` 將連線掛入同一 guild room
- 連線成功先推送 `snapshot`（房間內現有角色位置）
- 客戶端持續送 `pose`（x/y/facing/moving）
- 後端過濾非法資料後廣播給同 guild 其他 session
- `PresenceHub` 預設為 in-memory；設定 `REDIS_URL` 後會啟用 Redis pub/sub 跨節點同步

注意：
- `REDIS_URL` 未設定時仍是單節點 in-memory 模式

## 6. 資料庫與 SeaORM 模型

### 6.1 主要表

- `users`
  - `id`, `email`, `password_hash`, `hunter_tag`, `current_role`, `created_at`
- `guilds`
  - `id`, `name`, `owner_id`, `invite_code`
- `hunters`
  - `id`, `guild_id`, `user_id`, `player_id`, `name`, `avatar_type`
  - `level`, `xp`, `coins`, `pin_code`, `guild_role`, `motto`
- `quests`
  - `id`, `guild_id`, `title`, `description`, `reward_xp`, `reward_coins`, `stat_category`, `status`
  - `stat_category` ENUM: `STR | INT | AGI | CHA | VIT | NONE`
- `friend_links`
  - `id`, `player_id`, `friend_id`, `created_at`
- `friend_requests`
  - `id`, `requester_hunter_id`, `target_hunter_id`, `status`, `created_at`, `responded_at`
- `guild_invites`
  - `id`, `guild_id`, `inviter_hunter_id`, `invited_hunter_id`, `status`, `created_at`, `responded_at`

### 6.2 關聯摘要

- `users 1 -> many guilds`（owner）
- `guilds 1 -> many hunters`
- `guilds 1 -> many quests`
- `hunters` 與 `users` 透過 `user_id` 關聯（可空，刪 user 時 set null）
- `friend_links` / `friend_requests` / `guild_invites` 均透過 hunter id 建立關係

### 6.3 Migration 狀態

- `000001`：保留（no-op）
- `000002`：核心四表（users/guilds/hunters/quests）
- `000003`：`player_id`、`friend_links`、`guild_invites`
- `000004`：`users.hunter_tag/current_role`、`friend_requests`
- `000005`：`hunters.user_id/guild_role` 與 owner hunter backfill
- `000006`：`hunters.motto`
- `000007`：`quests.stat_category`（RPG 能力標籤）
- `000008`：`hunters.pin_code` 擴充為 hash 長度並批次遷移 Argon2
- `000009`：`quests.stat_category` 轉為 PostgreSQL ENUM（含 `NONE` 預設）

## 7. 前端架構細節

### 7.1 App 入口與路由守衛

- `apps/client_flutter/lib/main.dart`
  - 支援 `ENABLE_DEVICE_PREVIEW`（非 release 模式）
- `apps/client_flutter/lib/app/app.dart`
  - `_AuthGate` 根據 `authControllerProvider` 狀態切換頁面
  - 未登入 -> `UnifiedAuthPage`
  - 已登入 -> `GameShellPage`

### 7.2 狀態管理（Riverpod）

- `authControllerProvider`
  - 啟動時讀取 secure storage
  - 呼叫 `/api/v1/auth/me` 驗證 session
- `apiClientProvider`
  - 將 JWT 注入後續 API 請求
- 其他控制器
  - `questController`
  - `hunterDirectoryController`
  - `socialController`
  - `progressionController`

### 7.3 遊戲層（Flame）

- `game_shell_page.dart`
  - HUD、互動按鈕、資料面板
  - WebSocket 連線管理與重連策略
- `bitbond_game.dart`
  - 酒館場景、家具碰撞、互動距離判定
  - 浮動虛擬搖桿控制角色
  - 本地玩家控制 + 遠端玩家插值渲染

## 8. 本地開發啟動（建議流程）

### 8.1 前置條件

- Docker / Docker Compose
- Rust toolchain
- Flutter SDK

### 8.2 環境變數

```bash
cp .env.example .env
```

至少要確認：
- `DATABASE_URL`
- `JWT_SECRET`（>= 32 字元）
- `BIND_ADDR`（預設 `0.0.0.0:18080`）
- `REDIS_URL`（選填；多節點 Realtime 才需要）
- `FIREBASE_PROJECT_ID`（若要使用 Google Sign-In / Firebase 驗章）

### 8.3 啟動 PostgreSQL

```bash
docker compose -f infra/docker-compose.yml up -d
```

預設 host port 為 `5433`，避免與本機 `5432` 衝突。

### 8.4 啟動後端

```bash
cargo run -p the_bit_and_bond_server
```

健康檢查：

```bash
curl http://127.0.0.1:18080/api/v1/health
```

### 8.5 啟動 Flutter Web（方便平板測試）

```bash
cd apps/client_flutter
flutter pub get
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 18081 \
  --dart-define=APP_ENV=local \
  --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

瀏覽器開啟：
- 同機：`http://localhost:18081`
- 區網裝置：`http://<你的電腦區網IP>:18081`

可選環境參數（建議 staging / production）：
- `APP_ENV=staging|production`
- `STAGING_API_BASE_URL=...`
- `PRODUCTION_API_BASE_URL=...`
- `MOBILE_API_BASE_URL=...`（原生裝置連線後端時）

## 9. 測試與品質控管

### Rust

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test -p the_bit_and_bond_server --locked
```

### Flutter

```bash
cd apps/client_flutter
flutter analyze
flutter test
```

效能驗證流程：
- [docs/performance_playbook.md](/Users/ivesliu/Documents/chen-leveling/docs/performance_playbook.md)

## 10. CI/CD（GitHub Actions）

- `CI`
  - Rust：fmt / clippy / test
  - Flutter：analyze / test
- `PR Preview Build`
  - 建置 Flutter web preview artifact
- `CD Build Artifacts`
  - 手動觸發，產出 Rust release binary + Flutter web bundle
- `Release`
  - Tag 觸發，建立 GitHub Release 並附上產物

## 11. 發版檢查表

- 請先跑一遍：
  [docs/release_checklist.md](/Users/ivesliu/Documents/chen-leveling/docs/release_checklist.md)
- TestFlight 內測流程：
  [docs/testflight_internal_beta_checklist.md](/Users/ivesliu/Documents/chen-leveling/docs/testflight_internal_beta_checklist.md)

## 12. 目前已知限制

- Realtime 在 `REDIS_URL` 未設定時仍為單節點 in-memory
- Pub/Sub 僅做即時位置同步；歷史回放與持久化仍在 DB 層處理

## 13. 協作建議

- 所有新功能先補 migration + entity，再補 API/前端
- PR 請附：
  - 變更範圍
  - 測試結果
  - 若有 UI 變更請附圖
- 建議以 `feat/*`, `fix/*`, `chore/*` 命名分支並走 PR 合併
