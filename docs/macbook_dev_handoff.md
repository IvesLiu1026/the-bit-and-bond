# MacBook AI Agent Handoff

這份文件是給接手 `The Bit and Bond` 的 MacBook dev。
目標不是重講產品願景，而是讓新dev能快速判斷：

- 目前 repo 已經做到哪裡
- 哪些檔案是核心入口
- 哪些本機設定不會跟著 git 走，但在 Mac 上一定要補
- 哪些東西現在不要碰，避免走回舊架構

## 1. 專案現況摘要

目前專案是：

- Monorepo
- Rust 後端：Axum + SeaORM + PostgreSQL
- Flutter 前端：Flame + Riverpod
- 即時多人位置同步：WebSocket
- 語音房：LiveKit token 由 Rust 後端發，Flutter 前端加入房間
- 聊天：後端有 chat API，前端已有 campfire/chat UI 與 controller

目前前端主場景已經不再是單純米色 dashboard，而是 tavern / guild hall 路線：

- 主背景已切成像素酒館圖
- 角色採 top-down sprite animation
- 有浮動虛擬搖桿
- 有互動家具熱區：
  - 任務佈告欄
  - 公會長書桌
  - 公會儲物箱
  - 營火語音吧台
  - 公會商人

## 2. MacBook Agent 第一輪應該先讀的檔案

### 前端核心

- `apps/client_flutter/lib/features/game/game_shell_page.dart`
- `apps/client_flutter/lib/features/game/chen_game.dart`
- `apps/client_flutter/lib/features/game/chen_game_environment.part.dart`
- `apps/client_flutter/lib/features/game/chen_game_furniture.part.dart`
- `apps/client_flutter/lib/features/game/chen_game_character.part.dart`
- `apps/client_flutter/lib/state/voice_chat_controller.dart`
- `apps/client_flutter/lib/core/network/api_client.dart`
- `apps/client_flutter/lib/core/network/auth_api_client.dart`
- `apps/client_flutter/lib/features/auth/unified_auth_page.dart`

### 後端核心

- `apps/server/src/main.rs`
- `apps/server/src/config.rs`
- `apps/server/src/app.rs`
- `apps/server/src/auth.rs`
- `apps/server/src/jwt.rs`
- `apps/server/src/extractors.rs`
- `apps/server/src/api/realtime.rs`
- `apps/server/src/api/voice.rs`
- `apps/server/src/api/chat.rs`
- `apps/server/src/api/shop.rs`
- `apps/server/src/api/inventory.rs`
- `apps/server/src/api/quests.rs`
- `apps/server/src/presence.rs`

### 資料模型 / migration

- `apps/server/entity/src`
- `apps/server/migration/src`

### 設計 / 架構文件

- `README.md`
- `docs/architecture.md`
- `docs/UI_DESIGN.md`
- `docs/tavern_asset_sources.md`

## 3. 目前已完成的重點功能

### 帳號與登入

- 使用 unified auth
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `account` 可用 `player_id` 或 `email`
- `secret` 目前支援 PIN / 密碼共用入口
- PIN 與密碼都已改為 Argon2 hash

### 遊戲主場景

- 已有可控制角色
- 有多人同步角色
- 有浮動搖桿
- camera 會跟著受控角色
- 目前 tavern 背景已接入，並開始把家具改為背景內嵌熱區

### 任務 / 成長 / 商店 / 背包

- 任務建立、提交、審核
- quest `stat_category` 已落地
- reward ledger 已存在
- 商店商品、購買、背包、道具核銷 API 已存在
- 前端已有 shop / inventory dialog 與 controller

### 語音 / 聊天

- 後端已有 LiveKit token API
- 本地 infra 已有 `docker-compose.voice.yml`
- 前端已有 campfire voice dialog
- 前端已有聊天室 UI 與 chat history refresh

## 4. 目前仍需持續追的問題

這些是 MacBook agent 到位後，建議優先驗證的項目：

1. iPhone / iPad 原生執行下，角色是否穩定可見
2. 營火語音 join -> leave -> rejoin 狀態機是否完全穩定
3. 聊天送出後是否即時顯示、離開營火後重進是否能繼續看紀錄
4. 手機小螢幕下的響應式布局是否仍有擠壓
5. 新 tavern 背景下，碰撞箱是否仍有不合理區塊

## 4.1 兩個重要陷阱

這兩點一定要先知道，不然很容易在 Mac 上浪費時間追錯方向。

### 陷阱 A：`infra/seed.sql` 是舊世界，不要用

`infra/seed.sql` 仍然是舊的：

- `households`
- `members`
- `characters`
- `quest_templates`
- `quest_instances`

現在正式後端已經是：

- `users`
- `guilds`
- `hunters`
- `quests`
- `guild_items`
- `hunter_inventories`
- `hunter_reward_ledger`

所以：

- 不要執行 `infra/seed.sql`
- 不要期待它能建立現在可登入的 demo 帳號
- MacBook agent 應該補新的 seed / bootstrap 流程

### 陷阱 B：`demo_master` / `demo_member` 不是 repo 真相

目前能用的 demo 帳號，是 Windows / WSL 本機資料庫內的狀態，不是 repo 內可重建的資料。

這代表：

- 你在 Mac 上 pull 下來之後，不會自然擁有 `demo_master`
- 你也不會自然擁有商店商品、背包、現成聊天紀錄
- 這些都需要重新建立或補 seed script

正確心態是：

- repo 提供的是程式碼與 migration
- demo data 目前還不是正式基礎設施的一部分

## 5. 這次 Windows / WSL 開發新增、應該推上去的內容

以下內容屬於 repo 正式程式碼或正式素材，建議推上去：

### 代碼

- `apps/client_flutter/lib/features/auth/unified_auth_page.dart`
- `apps/client_flutter/lib/features/game/chen_game.dart`
- `apps/client_flutter/lib/features/game/chen_game_character.part.dart`
- `apps/client_flutter/lib/features/game/chen_game_environment.part.dart`
- `apps/client_flutter/lib/features/game/chen_game_furniture.part.dart`
- `apps/client_flutter/lib/features/game/game_shell_page*.dart`
- `apps/client_flutter/lib/state/voice_chat_controller.dart`
- `apps/client_flutter/pubspec.yaml`
- `apps/client_flutter/test/unified_auth_page_test.dart`
- `apps/client_flutter/test/widget_test.dart`
- `apps/client_flutter/tool/serve_web_no_cache.py`

### 正式素材

- `apps/client_flutter/assets/environment/tavern_main_room.png`
- `apps/client_flutter/assets/environment/campfire_sprite_sheet.png`

### 文件

- `docs/tavern_asset_sources.md`
- 這份文件本身

## 6. 不建議推上去的東西

### 絕對不要推

- `.env`
- `.env.*`
- `~/.config/ngrok/ngrok.yml`
- Apple signing / provisioning / cert 檔
- 任何含 token / secret / authtoken 的本機檔案

### 建議不要推

- `apps/client_flutter/assets/external/`
  - 這裡是第三方原始下載包與授權參考
  - 用來研究來源，不是執行時必要素材
- `output/`
  - 研究輸出與拼圖圖檔
- `__pycache__/`

## 7. 在 MacBook 上「不會從 git 帶過去，但一定要有」的東西

這段最重要。

### 7.1 `.env`

MacBook 本機一定要自己建立 `.env`。
可以用 repo 內的 `.env.example` 當模板。

最少要補這些：

- `DATABASE_URL`
- `BIND_ADDR`
- `JWT_SECRET`
- `AUTO_MIGRATE`

如果要測多人 / 跨節點 presence：

- `REDIS_URL`

如果要測語音：

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `LIVEKIT_TOKEN_TTL_SECONDS`
- `LIVEKIT_CHAT_TOPIC`

### 7.2 iOS 原生開發依賴

MacBook 本機一定要有：

- Xcode
- Xcode Command Line Tools
- CocoaPods
- Flutter SDK
- Rust toolchain
- Docker Desktop

建議先跑：

```bash
flutter doctor -v
xcode-select -p
pod --version
rustup show
docker --version
```

### 7.3 Apple 簽章 / Team 設定

這些不會跟著 git：

- Apple Developer Team
- Bundle Identifier 對應的 signing
- Provisioning Profile
- 本機鑰匙圈內的簽章憑證

如果沒有這些，Mac 上可以跑模擬器，但不能順利裝到實機。

### 7.4 ngrok

如果要從 iPhone 真機透過外網測 web 版：

- Mac 本機要安裝 ngrok
- 要重新登入自己的 authtoken
- `~/.config/ngrok/ngrok.yml` 不會從 git 帶過去

### 7.5 Demo 測試資料

現在 repo 裡沒有新的正式 seed 流程來建立：

- `demo_master`
- `demo_member`
- 商店商品
- 背包物品

也就是說，這些 demo 帳號目前是「本機資料庫狀態」，不是 repo 內可重建真相。

MacBook agent 應該把這件事視為待補技術債：

1. 新增新的 seed script，對齊現在的 unified auth / guild / hunter / shop schema
2. 不要使用 `infra/seed.sql`

原因：

- `infra/seed.sql` 仍然是舊 `households / members / characters / quest_templates` 模型
- 跟現在後端 schema 不一致
- 不能拿來初始化目前這版系統

## 8. 資料庫建立流程

這段是給 MacBook agent 的實作型指引。

### 8.1 最簡單路線：直接用 Docker Compose

repo 已有：

- `infra/docker-compose.yml`

Postgres 預設設定是：

- user: `chen`
- password: `chen`
- db: `the_bit_and_bond`
- host port: `5433`

啟動：

```bash
docker compose -f infra/docker-compose.yml up -d
```

確認：

```bash
docker ps
```

如果要手動檢查資料庫：

```bash
psql postgres://chen:chen@127.0.0.1:5433/the_bit_and_bond -c '\dt'
```

### 8.2 `.env` 應該怎麼配

至少要有：

```env
DATABASE_URL=postgres://chen:chen@127.0.0.1:5433/the_bit_and_bond
BIND_ADDR=0.0.0.0:18080
AUTO_MIGRATE=true
JWT_SECRET=<長度至少 32 的 secret>
```

如果要測多節點 presence：

```env
REDIS_URL=redis://127.0.0.1:6379
```

如果要測語音：

```env
LIVEKIT_URL=ws://127.0.0.1:7880
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=devsecret
LIVEKIT_TOKEN_TTL_SECONDS=7200
LIVEKIT_CHAT_TOPIC=guild.chat
```

### 8.3 migration 怎麼跑

目前 server 在 `AUTO_MIGRATE=true` 時，啟動會自動跑 migration。

也就是：

```bash
cargo run -p the_bit_and_bond_server
```

會自動：

1. 連線資料庫
2. 跑 SeaORM migration
3. 啟動 API server

如果要手動跑 migration，也可以：

```bash
cargo run -p migration -- up
```

或看 migration 狀態：

```bash
cargo run -p migration -- status
```

### 8.4 不用 Docker，自己在 Mac 裝 PostgreSQL 也可以

如果 Mac 上自己裝 PostgreSQL，也沒問題，但要自己建立：

- user
- database
- 對應的 `DATABASE_URL`

例如：

```bash
createdb the_bit_and_bond
```

然後把 `.env` 改成對應的連線字串。

但實務上，對新的 AI Agent 來說，直接用 `docker-compose.yml` 最少坑。

## 9. MacBook 上建議的啟動順序

### 8.1 後端資料服務

```bash
docker compose -f infra/docker-compose.yml up -d
```

如果要測語音：

```bash
docker compose -f infra/docker-compose.voice.yml up -d
```

### 8.2 後端 API

```bash
cargo run -p the_bit_and_bond_server
```

健康檢查：

```bash
curl http://127.0.0.1:18080/api/v1/health
```

### 8.3 Flutter

先取依賴：

```bash
cd apps/client_flutter
flutter pub get
```

跑分析與測試：

```bash
flutter analyze
flutter test
```

### 8.4 iOS Simulator

```bash
flutter devices
flutter run -d ios \
  --dart-define=MOBILE_API_BASE_URL=http://127.0.0.1:18080
```

如果是實機，不要用 `127.0.0.1`，要改成 Mac 的區網 IP。

### 8.5 iPhone 實機

```bash
flutter run -d <your-iphone-device-id> \
  --dart-define=MOBILE_API_BASE_URL=http://<macbook-lan-ip>:18080
```

如果語音要連本機 LiveKit，也要把 LiveKit 相關 URL 改成 Mac 的區網 IP。

## 10. MacBook AI Agent 的建議第一批任務

依優先順序：

1. 補一個新的 seed 系統
   - 建 demo master/member
   - 建商店商品
   - 建一小批任務
   - 讓本地測試可重現

2. 在 iOS Simulator / iPhone 真機驗證：
   - 角色顯示
   - 搖桿
   - camera follow
   - campfire join/leave/rejoin
   - chat send/history

3. 針對手機 layout 做真機修正
   - 不是 web view 修正，而是原生 iOS 尺寸修正

4. 把 tavern 場景剩餘的程序化家具逐步換成正式 sprite/tiles

5. 如果要做自動 UI 驗證，再決定：
   - 裝 Playwright browser runtime
   - 或直接用 iOS simulator screenshot pipeline

## 11. 目前的 git 決策建議

如果現在要從 Windows / WSL 推一版讓 MacBook 接手，我建議：

### 應該 commit / push

- 正式程式碼
- 正式環境素材 `assets/environment`
- 文件
- 測試

### 不要 commit / push

- `.env`
- ngrok config
- 原始第三方下載資料夾 `assets/external`
- `output`
- 任意本機 cache / pycache

## 12. 一句話版本

MacBook agent 不應該從零摸索。
它應該把目前 repo 視為：

- 「後端 API 已成形」
- 「前端 tavern 場景已接上正式像素背景」
- 「語音/聊天/商店/背包 都已有骨架與 API」
- 「現在最需要的是：真機驗證、seed 可重現、iOS 細修」
