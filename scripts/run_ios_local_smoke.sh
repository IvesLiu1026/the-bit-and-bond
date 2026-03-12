#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="${1:-iPhone 17}"
SMOKE_API_PORT="${SMOKE_API_PORT:-}"
API_BASE_URL="${API_BASE_URL:-}"
USE_EXISTING_API="${USE_EXISTING_API:-0}"
SERVER_LOG="${SERVER_LOG:-/tmp/bitbond-ios-local-smoke-server.log}"
VOICE_SMOKE_MODE="${VOICE_SMOKE_MODE:-graceful}"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}

wait_for_api() {
  local attempts=0
  until curl -fsS "$API_BASE_URL/api/v1/health" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 40 ]]; then
      echo "API server did not become ready at $API_BASE_URL" >&2
      if [[ -f "$SERVER_LOG" ]]; then
        tail -n 120 "$SERVER_LOG" >&2 || true
      fi
      return 1
    fi
    sleep 1
  done
  return 0
}

pick_free_port() {
  python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

start_smoke_api_server() {
  (
    cd "$REPO_ROOT"
    BIND_ADDR="127.0.0.1:${SMOKE_API_PORT}" \
    LIVEKIT_URL="${LOCAL_LIVEKIT_URL:-ws://127.0.0.1:7880}" \
    LIVEKIT_API_KEY="${LOCAL_LIVEKIT_API_KEY:-devkey}" \
    LIVEKIT_API_SECRET="${LOCAL_LIVEKIT_API_SECRET:-devsecret}" \
    LIVEKIT_CHAT_TOPIC="${LOCAL_LIVEKIT_CHAT_TOPIC:-guild.chat}" \
    cargo run -p the_bit_and_bond_server
  ) >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
}

restart_smoke_api_server_with_free_port() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
    SERVER_PID=""
  fi
  SMOKE_API_PORT="$(pick_free_port)"
  API_BASE_URL="http://127.0.0.1:${SMOKE_API_PORT}"
  echo "Smoke API port is busy; using $SMOKE_API_PORT instead." >&2
  start_smoke_api_server
}

trap cleanup EXIT

if [[ -z "$SMOKE_API_PORT" ]]; then
  SMOKE_API_PORT="$(pick_free_port)"
fi

DEFAULT_API_BASE_URL="http://127.0.0.1:${SMOKE_API_PORT}"
if [[ -z "$API_BASE_URL" ]]; then
  API_BASE_URL="$DEFAULT_API_BASE_URL"
fi

"$REPO_ROOT/scripts/bootstrap_local_demo.sh" --services-only

if [[ "$USE_EXISTING_API" == "1" ]]; then
  wait_for_api
else
  if lsof -iTCP:"$SMOKE_API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    if [[ "$API_BASE_URL" != "$DEFAULT_API_BASE_URL" ]]; then
      cat <<EOF >&2
Smoke API port is already in use:
  $SMOKE_API_PORT

Set SMOKE_API_PORT to a free port, or run with USE_EXISTING_API=1.
EOF
      exit 1
    fi
    restart_smoke_api_server_with_free_port
  else
    start_smoke_api_server
  fi

  if ! wait_for_api; then
    if grep -q 'AddrInUse' "$SERVER_LOG" && [[ "$API_BASE_URL" == "$DEFAULT_API_BASE_URL" ]]; then
      restart_smoke_api_server_with_free_port
      wait_for_api
    else
      exit 1
    fi
  fi
fi

API_BASE_URL="$API_BASE_URL" "$REPO_ROOT/scripts/seed_demo_accounts.sh"

if ! xcrun simctl list devices available | grep -Fq "$DEVICE_NAME"; then
  DEVICE_NAME="$(
    xcrun simctl list devices available |
      awk -F' \\(' '/iPhone/ {gsub(/^ +/, "", $1); print $1; exit}'
  )"
fi

if [[ -z "$DEVICE_NAME" ]]; then
  echo "No available iPhone simulator found." >&2
  exit 1
fi

xcrun simctl boot "$DEVICE_NAME" >/dev/null 2>&1 || true
open -a Simulator

cd "$REPO_ROOT/apps/client_flutter"
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_local_smoke_test.dart \
  -d "$DEVICE_NAME" \
  --dart-define=APP_ENV=local \
  --dart-define=MOBILE_API_BASE_URL="$API_BASE_URL" \
  --dart-define=SMOKE_MEDIA_UPLOADS=true \
  --dart-define=VOICE_SMOKE_MODE="$VOICE_SMOKE_MODE"
