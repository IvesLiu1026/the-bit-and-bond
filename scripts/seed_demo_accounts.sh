#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:18080}"
DB_CONTAINER="${DB_CONTAINER:-the_bit_and_bond_postgres}"
DB_NAME="${DB_NAME:-the_bit_and_bond}"
DB_USER="${DB_USER:-chen}"

API_STATUS=""
API_BODY=""

api_post() {
  local path="$1"
  local body="$2"
  local token="${3:-}"
  local tmp
  tmp="$(mktemp)"

  if [[ -n "$token" ]]; then
    API_STATUS="$(
      curl -sS \
        -o "$tmp" \
        -w '%{http_code}' \
        -X POST \
        "$BASE_URL$path" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H "Authorization: Bearer $token" \
        --data "$body"
    )"
  else
    API_STATUS="$(
      curl -sS \
        -o "$tmp" \
        -w '%{http_code}' \
        -X POST \
        "$BASE_URL$path" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        --data "$body"
    )"
  fi

  API_BODY="$(cat "$tmp")"
  rm -f "$tmp"
}

api_get() {
  local path="$1"
  local token="${2:-}"
  local tmp
  tmp="$(mktemp)"

  if [[ -n "$token" ]]; then
    API_STATUS="$(
      curl -sS \
        -o "$tmp" \
        -w '%{http_code}' \
        "$BASE_URL$path" \
        -H 'Accept: application/json' \
        -H "Authorization: Bearer $token"
    )"
  else
    API_STATUS="$(
      curl -sS \
        -o "$tmp" \
        -w '%{http_code}' \
        "$BASE_URL$path" \
        -H 'Accept: application/json'
    )"
  fi

  API_BODY="$(cat "$tmp")"
  rm -f "$tmp"
}

psql_exec() {
  docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME"
}

assert_server_ready() {
  api_get "/api/v1/health"
  if [[ "$API_STATUS" != "200" ]]; then
    echo "Seed failed: API server is not ready at $BASE_URL" >&2
    echo "status=$API_STATUS body=$API_BODY" >&2
    exit 1
  fi
}

assert_db_ready() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER"; then
    echo "Seed failed: database container $DB_CONTAINER is not running" >&2
    exit 1
  fi
}

ensure_login_or_register() {
  local player_id="$1"
  local pin_code="$2"
  local display_name="$3"

  local login_payload
  login_payload="$(
    jq -nc \
      --arg account "$player_id" \
      --arg secret "$pin_code" \
      '{account: $account, secret: $secret}'
  )"
  api_post "/api/v1/auth/login" "$login_payload"
  if [[ "$API_STATUS" == "200" ]]; then
    printf '%s\n' "$API_BODY"
    return 0
  fi

  local register_payload
  register_payload="$(
    jq -nc \
      --arg account "$player_id" \
      --arg secret "$pin_code" \
      --arg display_name "$display_name" \
      '{account: $account, secret: $secret, display_name: $display_name, avatar_type: "novice"}'
  )"
  api_post "/api/v1/auth/register" "$register_payload"
  if [[ "$API_STATUS" != "201" ]]; then
    echo "Seed failed while creating $player_id" >&2
    echo "status=$API_STATUS body=$API_BODY" >&2
    exit 1
  fi

  printf '%s\n' "$API_BODY"
}

ensure_member_hunter() {
  local master_token="$1"
  local expected_guild_id="$2"
  local player_id="$3"
  local pin_code="$4"
  local display_name="$5"

  local login_payload
  login_payload="$(
    jq -nc \
      --arg account "$player_id" \
      --arg secret "$pin_code" \
      '{account: $account, secret: $secret}'
  )"
  api_post "/api/v1/auth/login" "$login_payload"
  if [[ "$API_STATUS" == "200" ]]; then
    local existing_guild_id
    existing_guild_id="$(printf '%s' "$API_BODY" | jq -r '.guild_id')"
    if [[ "$existing_guild_id" != "$expected_guild_id" ]]; then
      echo "Seed failed: $player_id already exists in another guild ($existing_guild_id)" >&2
      exit 1
    fi
    printf '%s\n' "$API_BODY"
    return 0
  fi

  local create_payload
  create_payload="$(
    jq -nc \
      --arg name "$display_name" \
      --arg avatar_type "novice" \
      --arg pin_code "$pin_code" \
      --arg player_id "$player_id" \
      '{name: $name, avatar_type: $avatar_type, pin_code: $pin_code, player_id: $player_id}'
  )"
  api_post "/api/v1/hunters" "$create_payload" "$master_token"
  if [[ "$API_STATUS" != "201" ]]; then
    echo "Seed failed while creating member hunter $player_id" >&2
    echo "status=$API_STATUS body=$API_BODY" >&2
    exit 1
  fi

  api_post "/api/v1/auth/login" "$login_payload"
  if [[ "$API_STATUS" != "200" ]]; then
    echo "Seed failed while logging into member hunter $player_id" >&2
    echo "status=$API_STATUS body=$API_BODY" >&2
    exit 1
  fi

  printf '%s\n' "$API_BODY"
}

seed_demo_data() {
  local master_guild_id="$1"
  local master_hunter_id="$2"
  local member_hunter_id="$3"
  local friend_guild_id="$4"
  local friend_hunter_id="$5"

  psql_exec <<SQL
INSERT INTO quests (id, guild_id, title, description, reward_xp, reward_coins, stat_category, status)
VALUES
  ('10000000-0000-0000-0000-000000000101', '$master_guild_id', '晨間酒館巡邏', '確認桌椅整齊、壁爐安全，回報今天的酒館狀態。', 80, 35, 'STR', 'available'),
  ('10000000-0000-0000-0000-000000000102', '$master_guild_id', '營火故事整理', '把今天大家分享的故事整理成公會筆記。', 120, 40, 'INT', 'available'),
  ('10000000-0000-0000-0000-000000000103', '$master_guild_id', '補給箱盤點', '盤點藥水、食物與工具，缺貨就記在看板上。', 60, 25, 'VIT', 'available'),
  ('10000000-0000-0000-0000-000000000104', '$master_guild_id', '幫營火添柴', '幫酒館營火補滿木柴，讓今晚語音吧台保持熱鬧。', 50, 20, 'AGI', 'pending_review'),
  ('10000000-0000-0000-0000-000000000105', '$master_guild_id', '修復酒館招牌', '把門口歪掉的木招牌重新固定好。', 100, 60, 'CHA', 'completed'),
  ('10000000-0000-0000-0000-000000000201', '$friend_guild_id', '北方哨站送信', '替遠行公會把補給通知送到北方哨站。', 70, 20, 'AGI', 'available'),
  ('10000000-0000-0000-0000-000000000202', '$friend_guild_id', '夜間觀星筆記', '記錄今晚的星象與旅程路線。', 90, 28, 'INT', 'available')
ON CONFLICT (id) DO UPDATE
SET guild_id = EXCLUDED.guild_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    reward_xp = EXCLUDED.reward_xp,
    reward_coins = EXCLUDED.reward_coins,
    stat_category = EXCLUDED.stat_category,
    status = EXCLUDED.status;

INSERT INTO quests (
  id,
  guild_id,
  title,
  description,
  reward_xp,
  reward_coins,
  stat_category,
  category,
  assigned_hunter_id,
  created_by_hunter_id,
  cadence,
  streak_count,
  best_streak,
  completions_count,
  proof_note,
  proof_submitted_at,
  last_completed_at,
  last_review_note,
  updated_at,
  status
)
VALUES
  (
    '10000000-0000-0000-0000-000000000301',
    '$master_guild_id',
    '晚餐後喝水回報',
    '晚餐後補滿今天最後一杯水，完成後用一句話記錄。',
    15,
    4,
    'VIT',
    'habit',
    '$member_hunter_id',
    '$master_hunter_id',
    'daily',
    3,
    5,
    8,
    '昨天晚餐後喝完 500ml。',
    NOW() - INTERVAL '1 day',
    CURRENT_DATE - 1,
    '保持得很好',
    NOW(),
    'available'
  ),
  (
    '10000000-0000-0000-0000-000000000302',
    '$master_guild_id',
    '睡前書桌重置',
    '睡前把桌面整理好，再送出今天的整理證明。',
    10,
    6,
    'STR',
    'habit',
    '$member_hunter_id',
    '$master_hunter_id',
    'daily',
    2,
    4,
    6,
    '桌面已整理好，只剩書包待收。',
    NOW() - INTERVAL '18 minutes',
    CURRENT_DATE - 1,
    NULL,
    NOW(),
    'pending_review'
  ),
  (
    '10000000-0000-0000-0000-000000000303',
    '$master_guild_id',
    '週末家庭散步',
    '每週至少一次和家人一起散步 20 分鐘。',
    30,
    12,
    'AGI',
    'habit',
    '$member_hunter_id',
    '$master_hunter_id',
    'weekly',
    1,
    2,
    3,
    '上週日完成河堤散步。',
    NOW() - INTERVAL '8 days',
    CURRENT_DATE - 8,
    '本週再接再厲',
    NOW(),
    'available'
  )
ON CONFLICT (id) DO UPDATE
SET guild_id = EXCLUDED.guild_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    reward_xp = EXCLUDED.reward_xp,
    reward_coins = EXCLUDED.reward_coins,
    stat_category = EXCLUDED.stat_category,
    category = EXCLUDED.category,
    assigned_hunter_id = EXCLUDED.assigned_hunter_id,
    created_by_hunter_id = EXCLUDED.created_by_hunter_id,
    cadence = EXCLUDED.cadence,
    streak_count = EXCLUDED.streak_count,
    best_streak = EXCLUDED.best_streak,
    completions_count = EXCLUDED.completions_count,
    proof_note = EXCLUDED.proof_note,
    proof_submitted_at = EXCLUDED.proof_submitted_at,
    last_completed_at = EXCLUDED.last_completed_at,
    last_review_note = EXCLUDED.last_review_note,
    updated_at = EXCLUDED.updated_at,
    status = EXCLUDED.status;

INSERT INTO guild_items (id, guild_id, name, description, cost_coins, icon_tag, is_active)
VALUES
  ('20000000-0000-0000-0000-000000000101', '$master_guild_id', '冒險補給藥水', '喝下後讓冒險者恢復精神，適合任務前補給。', 25, 'POTION', true),
  ('20000000-0000-0000-0000-000000000102', '$master_guild_id', '營火烤棉花糖', '在營火旁慢慢烤到金黃，聊天時最搭。', 12, 'FOOD', true),
  ('20000000-0000-0000-0000-000000000103', '$master_guild_id', '修理工具卷', '記下今天要修的家具與工具，方便公會長派工。', 40, 'SCROLL', true),
  ('20000000-0000-0000-0000-000000000104', '$master_guild_id', '公會徽章貼紙', '貼在裝備箱上，讓大家知道你屬於旅人酒館。', 8, 'TICKET', true),
  ('20000000-0000-0000-0000-000000000201', '$friend_guild_id', '旅行羽毛筆', '遠行時記錄沿途見聞的輕便羽毛筆。', 15, 'SCROLL', true)
ON CONFLICT (guild_id, name) DO UPDATE
SET description = EXCLUDED.description,
    cost_coins = EXCLUDED.cost_coins,
    icon_tag = EXCLUDED.icon_tag,
    is_active = EXCLUDED.is_active;

INSERT INTO hunter_reward_ledger (id, hunter_id, quest_id, item_id, idempotency_key, event_type, stat_category, gained_xp, gained_coins, created_at)
VALUES
  ('30000000-0000-0000-0000-000000000101', '$master_hunter_id', NULL, NULL, '30000000-0000-0000-0000-000000009101', 'adjustment', 'CHA', 120, 250, NOW()),
  ('30000000-0000-0000-0000-000000000102', '$member_hunter_id', NULL, NULL, '30000000-0000-0000-0000-000000009102', 'adjustment', 'STR', 80, 45, NOW()),
  ('30000000-0000-0000-0000-000000000103', '$member_hunter_id', NULL, NULL, '30000000-0000-0000-0000-000000009103', 'adjustment', 'INT', 120, 70, NOW()),
  ('30000000-0000-0000-0000-000000000104', '$member_hunter_id', NULL, NULL, '30000000-0000-0000-0000-000000009104', 'adjustment', 'VIT', 60, 65, NOW()),
  ('30000000-0000-0000-0000-000000000105', '$friend_hunter_id', NULL, NULL, '30000000-0000-0000-0000-000000009105', 'adjustment', 'AGI', 90, 90, NOW())
ON CONFLICT (id) DO UPDATE
SET hunter_id = EXCLUDED.hunter_id,
    quest_id = EXCLUDED.quest_id,
    item_id = EXCLUDED.item_id,
    idempotency_key = EXCLUDED.idempotency_key,
    event_type = EXCLUDED.event_type,
    stat_category = EXCLUDED.stat_category,
    gained_xp = EXCLUDED.gained_xp,
    gained_coins = EXCLUDED.gained_coins,
    created_at = EXCLUDED.created_at;

UPDATE hunters
SET coins = 250,
    xp = 120,
    level = 2,
    motto = '今天也要讓酒館熱鬧起來'
WHERE id = '$master_hunter_id';

UPDATE hunters
SET coins = 180,
    xp = 260,
    level = 3,
    motto = '先接任務，再去營火聊天'
WHERE id = '$member_hunter_id';

UPDATE hunters
SET coins = 90,
    xp = 90,
    level = 1,
    motto = '從遠方帶回新的冒險故事'
WHERE id = '$friend_hunter_id';

INSERT INTO hunter_inventories (id, hunter_id, item_id, quantity, updated_at)
SELECT
  '40000000-0000-0000-0000-000000000101',
  '$member_hunter_id',
  id,
  2,
  NOW()
FROM guild_items
WHERE guild_id = '$master_guild_id' AND name = '冒險補給藥水'
ON CONFLICT (hunter_id, item_id) DO UPDATE
SET quantity = EXCLUDED.quantity,
    updated_at = EXCLUDED.updated_at;

INSERT INTO hunter_inventories (id, hunter_id, item_id, quantity, updated_at)
SELECT
  '40000000-0000-0000-0000-000000000102',
  '$member_hunter_id',
  id,
  1,
  NOW()
FROM guild_items
WHERE guild_id = '$master_guild_id' AND name = '營火烤棉花糖'
ON CONFLICT (hunter_id, item_id) DO UPDATE
SET quantity = EXCLUDED.quantity,
    updated_at = EXCLUDED.updated_at;

INSERT INTO hunter_inventories (id, hunter_id, item_id, quantity, updated_at)
SELECT
  '40000000-0000-0000-0000-000000000103',
  '$master_hunter_id',
  id,
  1,
  NOW()
FROM guild_items
WHERE guild_id = '$master_guild_id' AND name = '修理工具卷'
ON CONFLICT (hunter_id, item_id) DO UPDATE
SET quantity = EXCLUDED.quantity,
    updated_at = EXCLUDED.updated_at;

INSERT INTO friend_links (id, player_id, friend_id, created_at)
VALUES
  ('50000000-0000-0000-0000-000000000101', '$master_hunter_id', '$member_hunter_id', NOW()),
  ('50000000-0000-0000-0000-000000000102', '$member_hunter_id', '$master_hunter_id', NOW()),
  ('50000000-0000-0000-0000-000000000103', '$master_hunter_id', '$friend_hunter_id', NOW()),
  ('50000000-0000-0000-0000-000000000104', '$friend_hunter_id', '$master_hunter_id', NOW())
ON CONFLICT (player_id, friend_id) DO NOTHING;

INSERT INTO direct_messages (id, sender_hunter_id, recipient_hunter_id, conversation_key, client_message_id, content, sent_at)
VALUES
  (
    '60000000-0000-0000-0000-000000000101',
    '$master_hunter_id',
    '$member_hunter_id',
    CASE WHEN '$master_hunter_id' <= '$member_hunter_id'
      THEN '$master_hunter_id:$member_hunter_id'
      ELSE '$member_hunter_id:$master_hunter_id'
    END,
    '60000000-0000-0000-0000-000000009101',
    '晚餐後記得把喝水習慣送審給我，我幫你核准。',
    NOW() - INTERVAL '35 minutes'
  ),
  (
    '60000000-0000-0000-0000-000000000102',
    '$member_hunter_id',
    '$master_hunter_id',
    CASE WHEN '$master_hunter_id' <= '$member_hunter_id'
      THEN '$master_hunter_id:$member_hunter_id'
      ELSE '$member_hunter_id:$master_hunter_id'
    END,
    '60000000-0000-0000-0000-000000009102',
    '好，我等等整理完書桌就一起送。',
    NOW() - INTERVAL '29 minutes'
  ),
  (
    '60000000-0000-0000-0000-000000000103',
    '$friend_hunter_id',
    '$master_hunter_id',
    CASE WHEN '$friend_hunter_id' <= '$master_hunter_id'
      THEN '$friend_hunter_id:$master_hunter_id'
      ELSE '$master_hunter_id:$friend_hunter_id'
    END,
    '60000000-0000-0000-0000-000000009103',
    '週末要不要一起散步挑戰？我想開一條 weekly habit。',
    NOW() - INTERVAL '12 minutes'
  )
ON CONFLICT (id) DO UPDATE
SET sender_hunter_id = EXCLUDED.sender_hunter_id,
    recipient_hunter_id = EXCLUDED.recipient_hunter_id,
    conversation_key = EXCLUDED.conversation_key,
    client_message_id = EXCLUDED.client_message_id,
    content = EXCLUDED.content,
    sent_at = EXCLUDED.sent_at;
SQL
}

assert_server_ready
assert_db_ready

master_json="$(ensure_login_or_register "demo_master" "1111" "Demo Master")"
master_token="$(printf '%s' "$master_json" | jq -r '.access_token')"
master_guild_id="$(printf '%s' "$master_json" | jq -r '.guild_id')"
master_hunter_id="$(printf '%s' "$master_json" | jq -r '.hunter_id')"

member_json="$(ensure_member_hunter "$master_token" "$master_guild_id" "demo_member" "2222" "Demo Member")"
member_hunter_id="$(printf '%s' "$member_json" | jq -r '.hunter_id')"
friend_json="$(ensure_login_or_register "demo_friend" "3333" "Demo Friend")"
friend_guild_id="$(printf '%s' "$friend_json" | jq -r '.guild_id')"
friend_hunter_id="$(printf '%s' "$friend_json" | jq -r '.hunter_id')"

seed_demo_data \
  "$master_guild_id" \
  "$master_hunter_id" \
  "$member_hunter_id" \
  "$friend_guild_id" \
  "$friend_hunter_id"

printf '\nDemo accounts are ready:\n'
printf '  %-12s PIN %-4s role=%-6s guild=%s\n' \
  "demo_master" "1111" "master" "$(printf '%s' "$master_json" | jq -r '.guild_id')"
printf '  %-12s PIN %-4s role=%-6s guild=%s\n' \
  "demo_member" "2222" "member" "$(printf '%s' "$member_json" | jq -r '.guild_id')"
printf '  %-12s PIN %-4s role=%-6s guild=%s\n' \
  "demo_friend" "3333" "master" "$(printf '%s' "$friend_json" | jq -r '.guild_id')"
printf '\nDemo data seeded:\n'
  printf '  %s\n' "旅人酒館公會：5 個 task、3 個 habit、4 個 shop items、會員背包與初始金幣/XP"
  printf '  %s\n' "遠行公會：2 個 quest、1 個 shop item"
  printf '  %s\n' "好友關係：demo_master <-> demo_member，demo_master <-> demo_friend"
  printf '  %s\n' "私訊對話：demo_master <-> demo_member、demo_master <-> demo_friend"
