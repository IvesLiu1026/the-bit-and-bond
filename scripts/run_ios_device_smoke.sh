#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DEVICE="${1:-}"
SMOKE_API_PORT="${SMOKE_API_PORT:-}"
API_BASE_URL="${API_BASE_URL:-}"
USE_EXISTING_API="${USE_EXISTING_API:-0}"
SERVER_LOG="${SERVER_LOG:-/tmp/bitbond-ios-device-smoke-server.log}"
VOICE_SMOKE_MODE="${VOICE_SMOKE_MODE:-connect}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.thebitandbond.client}"
DEVICE_APP_RESET_MODE="${DEVICE_APP_RESET_MODE:-terminate}"
SERVER_PID=""
LOCAL_API_BASE_URL=""
DEFAULT_API_BASE_URL=""
SERVER_BIND_ADDR=""
PUBLIC_LIVEKIT_URL=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}

cleanup_stale_device_processes() {
  pkill -f "devicectl device install app --device ${TARGET_DEVICE} build/ios/iphoneos/Runner.app" >/dev/null 2>&1 || true
  pkill -f "xcodebuild -configuration Debug -quiet -allowProvisioningUpdates.*-destination id=${TARGET_DEVICE}" >/dev/null 2>&1 || true
  pkill -f "flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_local_smoke_test.dart -d ${TARGET_DEVICE}" >/dev/null 2>&1 || true
  pkill -f "iproxy .* --udid ${TARGET_DEVICE}" >/dev/null 2>&1 || true
  pkill -f "flutter logs -d ${TARGET_DEVICE}" >/dev/null 2>&1 || true
}

reset_device_app_installation() {
  local process_json
  process_json="$(mktemp)"
  if xcrun devicectl device info processes --device "$TARGET_DEVICE" --json-output "$process_json" >/dev/null 2>&1; then
    python3 - <<'PY' "$process_json" | while IFS= read -r pid; do
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

for process in payload.get("result", {}).get("runningProcesses", []):
    executable = process.get("executable", "")
    if executable.endswith("/Runner.app/Runner"):
        print(process.get("processIdentifier", ""))
PY
      [[ -n "$pid" ]] || continue
      xcrun devicectl device process terminate --device "$TARGET_DEVICE" --pid "$pid" --kill >/dev/null 2>&1 || true
    done
  fi
  rm -f "$process_json"

  if [[ "$DEVICE_APP_RESET_MODE" == "uninstall" ]]; then
    xcrun devicectl device uninstall app --device "$TARGET_DEVICE" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  fi
}

resolve_xcode_run_destination_name() {
  xcrun devicectl device info details --device "$TARGET_DEVICE" 2>/dev/null | python3 -c '
import sys

in_device_properties = False
for raw_line in sys.stdin:
    line = raw_line.strip()
    if line.startswith("▿ deviceProperties:"):
        in_device_properties = True
        continue
    if in_device_properties and line.startswith("▿ ") and not line.startswith("▿ deviceProperties:"):
        in_device_properties = False
    if in_device_properties and "• name:" in line:
        print(line.split("• name:", 1)[1].strip())
        break
'
}

xcode_last_scheme_action_status() {
  osascript <<'APPLESCRIPT'
tell application "Xcode"
  try
    if (count of workspace documents) = 0 then
      return "missing|false"
    end if
    set ws to active workspace document
    set actionResult to last scheme action result of ws
    return (status of actionResult as string) & "|" & (completed of actionResult as string)
  on error
    return "missing|false"
  end try
end tell
APPLESCRIPT
}

stop_xcode_scheme_action() {
  osascript <<'APPLESCRIPT' >/dev/null
tell application "Xcode"
  try
    if (count of workspace documents) > 0 then
      stop active workspace document
    end if
  end try
end tell
APPLESCRIPT
}

prewarm_xcode_debug_session() {
  local destination_name
  destination_name="$(resolve_xcode_run_destination_name)"
  if [[ -z "$destination_name" ]]; then
    echo "Warning: Could not resolve the Xcode run destination for device $TARGET_DEVICE." >&2
    return 1
  fi

  osascript <<APPLESCRIPT >/dev/null
tell application "Xcode"
  activate
  open POSIX file "$REPO_ROOT/apps/client_flutter/ios/Runner.xcworkspace"
  repeat 60 times
    if (count of workspace documents) > 0 and loaded of active workspace document is true then
      exit repeat
    end if
    delay 1
  end repeat
  if (count of workspace documents) = 0 or loaded of active workspace document is false then
    error "Runner workspace did not finish loading."
  end if
  set ws to active workspace document
  set active scheme of ws to first scheme of ws whose name is "Runner"
  set active run destination of ws to first run destination of ws whose name is "$destination_name"
  debug ws skip building false
end tell
APPLESCRIPT

  local attempts=0
  while [[ "$attempts" -lt 180 ]]; do
    local action_status
    action_status="$(xcode_last_scheme_action_status)"
    case "$action_status" in
      "succeeded|true")
        stop_xcode_scheme_action
        sleep 2
        return 0
        ;;
      "failed|true"|"error occurred|true"|"cancelled|true")
        echo "Warning: Xcode prewarm finished with status $action_status." >&2
        stop_xcode_scheme_action
        return 1
        ;;
    esac
    attempts=$((attempts + 1))
    sleep 1
  done

  echo "Warning: Xcode prewarm timed out waiting for a completed debug action." >&2
  stop_xcode_scheme_action
  return 1
}

ensure_xcode_ready() {
  open -a Xcode "$REPO_ROOT/apps/client_flutter/ios/Runner.xcworkspace" >/dev/null 2>&1 || true
  sleep 4
}

wait_for_api() {
  local attempts=0
  until curl -fsS "$LOCAL_API_BASE_URL/api/v1/health" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 40 ]]; then
      echo "API server did not become ready at $LOCAL_API_BASE_URL" >&2
      if [[ -f "$SERVER_LOG" ]]; then
        tail -n 120 "$SERVER_LOG" >&2 || true
      fi
      return 1
    fi
    sleep 1
  done
  return 0
}

format_url_host() {
  local host="$1"
  if [[ "$host" == *:* ]]; then
    echo "[$host]"
  else
    echo "$host"
  fi
}

pick_free_port() {
  python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

resolve_host_ip() {
  local usb_link_local
  usb_link_local="$(
    python3 - <<'PY'
import re
import subprocess

current = None
current_has_link_local = None
current_active = False
candidates = []

for raw_line in subprocess.check_output(["ifconfig"], text=True).splitlines():
    header = re.match(r'^([a-z0-9]+): flags=', raw_line)
    if header:
        if current and current_has_link_local and current_active:
            candidates.append((current, current_has_link_local))
        current = header.group(1)
        current_has_link_local = None
        current_active = False
        continue
    if current is None or not current.startswith("en"):
        continue
    link_local = re.search(r'\binet (169\.254\.\d+\.\d+)\b', raw_line)
    if link_local:
        current_has_link_local = link_local.group(1)
    if "status: active" in raw_line:
        current_active = True

if current and current_has_link_local and current_active:
    candidates.append((current, current_has_link_local))

if candidates:
    candidates.sort(key=lambda item: item[0])
    print(candidates[-1][1])
PY
  )"
  if [[ -n "$usb_link_local" ]]; then
    echo "$usb_link_local"
    return 0
  fi

  local tunnel_host_ipv6
  tunnel_host_ipv6="$(
    TARGET_DEVICE="$TARGET_DEVICE" python3 - <<'PY'
import ipaddress
import os
import re
import subprocess

target_device = os.environ.get("TARGET_DEVICE", "")
if not target_device:
    raise SystemExit(0)

try:
    details = subprocess.check_output(
        ["xcrun", "devicectl", "device", "info", "details", "--device", target_device],
        text=True,
        stderr=subprocess.DEVNULL,
    )
except subprocess.CalledProcessError:
    raise SystemExit(0)

tunnel_match = re.search(r"tunnelIPAddress:\s*([0-9a-fA-F:]+)", details)
if not tunnel_match:
    raise SystemExit(0)

network = ipaddress.ip_network(f"{tunnel_match.group(1)}/64", strict=False)
current = None
current_addresses = []
candidates = []

for raw_line in subprocess.check_output(["ifconfig"], text=True).splitlines():
    header = re.match(r"^(utun\d+): flags=", raw_line)
    if header:
      if current_addresses:
          candidates.extend(current_addresses)
      current = header.group(1)
      current_addresses = []
      continue
    if current is None:
      continue
    match = re.search(r"\binet6 ([0-9a-fA-F:]+)\b", raw_line)
    if not match:
      continue
    address = match.group(1)
    if address.startswith("fe80:"):
      continue
    try:
      parsed = ipaddress.ip_address(address)
    except ValueError:
      continue
    if parsed in network:
      current_addresses.append((current, address))

if current_addresses:
    candidates.extend(current_addresses)

if candidates:
    candidates.sort(key=lambda item: item[0])
    print(candidates[-1][1])
PY
  )"
  if [[ -n "$tunnel_host_ipv6" ]]; then
    echo "$tunnel_host_ipv6"
    return 0
  fi

  local interface
  interface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  if [[ -n "$interface" ]]; then
    local address
    address="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
    if [[ -n "$address" ]]; then
      echo "$address"
      return 0
    fi
  fi

  python3 - <<'PY'
import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    sock.connect(("1.1.1.1", 80))
    print(sock.getsockname()[0])
finally:
    sock.close()
PY
}

configure_api_addresses() {
  if [[ -z "${DEVICE_API_HOST:-}" ]]; then
    DEVICE_API_HOST="$(resolve_host_ip)"
  fi

  local formatted_host
  formatted_host="$(format_url_host "$DEVICE_API_HOST")"
  if [[ "$DEVICE_API_HOST" == *:* ]]; then
    SERVER_BIND_ADDR="[::]:${SMOKE_API_PORT}"
    LOCAL_API_BASE_URL="http://[::1]:${SMOKE_API_PORT}"
  else
    SERVER_BIND_ADDR="0.0.0.0:${SMOKE_API_PORT}"
    LOCAL_API_BASE_URL="http://127.0.0.1:${SMOKE_API_PORT}"
  fi
  DEFAULT_API_BASE_URL="http://${formatted_host}:${SMOKE_API_PORT}"
  PUBLIC_LIVEKIT_URL="${DEVICE_LIVEKIT_URL:-ws://${formatted_host}:7880}"
}

device_developer_mode_enabled() {
  local device_details
  device_details="$(xcrun devicectl device info details --device "$TARGET_DEVICE" 2>&1 || true)"
  grep -q "developerModeStatus: enabled" <<<"$device_details"
}

has_codesigning_identity() {
  local identity_output
  identity_output="$(security find-identity -v -p codesigning 2>&1 || true)"
  grep -Eq '[1-9][0-9]* valid identities found' <<<"$identity_output"
}

has_development_team() {
  local build_settings
  build_settings="$(
    cd "$REPO_ROOT/apps/client_flutter/ios" &&
      xcodebuild -workspace Runner.xcworkspace -scheme Runner -showBuildSettings 2>/dev/null || true
  )"
  grep -Eq 'DEVELOPMENT_TEAM = [A-Z0-9]+' <<<"$build_settings"
}

has_ios_simulator_runtime() {
  xcrun simctl list runtimes 2>/dev/null | grep -Eq 'iOS|com\.apple\.CoreSimulator\.SimRuntime\.iOS'
}

assert_device_smoke_prereqs() {
  if ! device_developer_mode_enabled; then
    cat <<EOF >&2
Connected iOS device is not ready for development.

Next steps on the device:
  1. Settings > Privacy & Security > Developer Mode
  2. Turn Developer Mode on
  3. Reboot if prompted, then confirm "Turn On"
  4. Re-run ./scripts/run_ios_device_smoke.sh
EOF
    exit 1
  fi

  if ! has_codesigning_identity; then
    cat <<EOF >&2
No local iOS development signing identity was found.

Next steps on this Mac:
  1. Open Xcode and sign in with your Apple ID
  2. Let Xcode create an iOS Development certificate
  3. Trust that certificate on the iPhone if prompted
  4. Re-run ./scripts/run_ios_device_smoke.sh
EOF
    exit 1
  fi

  if ! has_development_team; then
    cat <<EOF >&2
The iOS project does not have a Development Team configured for device builds.

Next steps in Xcode:
  1. Open apps/client_flutter/ios/Runner.xcworkspace
  2. Select the Runner target
  3. Go to Signing & Capabilities
  4. Choose your Team and keep automatic signing enabled
  5. Re-run ./scripts/run_ios_device_smoke.sh
EOF
    exit 1
  fi

  if ! has_ios_simulator_runtime; then
    cat <<EOF >&2
No iOS Simulator runtime is installed in Xcode.

Xcode still needs an iOS simulator runtime to compile storyboards and asset catalogs
for device builds.

Next steps in Xcode:
  1. Open Xcode > Settings > Components (or Platforms)
  2. Install an iOS Simulator runtime
  3. Re-run ./scripts/run_ios_device_smoke.sh
EOF
    exit 1
  fi
}

start_smoke_api_server() {
  (
    cd "$REPO_ROOT"
    BIND_ADDR="$SERVER_BIND_ADDR" \
    LIVEKIT_URL="$PUBLIC_LIVEKIT_URL" \
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
  configure_api_addresses
  API_BASE_URL="$DEFAULT_API_BASE_URL"
  echo "Smoke API port is busy; using $SMOKE_API_PORT instead." >&2
  start_smoke_api_server
}

resolve_connected_ios_device() {
  cd "$REPO_ROOT/apps/client_flutter"
  flutter devices --machine | python3 -c '
import json
import sys

devices = json.load(sys.stdin)
for device in devices:
    if device.get("targetPlatform") == "ios" and not device.get("emulator", False):
        print(device.get("id", ""))
        break
'
}

trap cleanup EXIT

if [[ -z "$SMOKE_API_PORT" ]]; then
  SMOKE_API_PORT="$(pick_free_port)"
fi

configure_api_addresses
if [[ -z "$API_BASE_URL" ]]; then
  API_BASE_URL="$DEFAULT_API_BASE_URL"
fi
echo "Using device API base URL: $API_BASE_URL"

if [[ -z "$TARGET_DEVICE" ]]; then
  TARGET_DEVICE="$(resolve_connected_ios_device)"
fi

if [[ -z "$TARGET_DEVICE" ]]; then
  cat <<'EOF' >&2
No connected physical iOS device found.

Next steps:
  1. Connect an iPhone or iPad via USB
  2. Unlock it and trust this Mac
  3. Enable Developer Mode if prompted
  4. Re-run ./scripts/run_ios_device_smoke.sh
EOF
  exit 1
fi

assert_device_smoke_prereqs

cleanup_stale_device_processes
reset_device_app_installation
ensure_xcode_ready
prewarm_xcode_debug_session || true
reset_device_app_installation

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

API_BASE_URL="$LOCAL_API_BASE_URL" "$REPO_ROOT/scripts/seed_demo_accounts.sh"

cd "$REPO_ROOT/apps/client_flutter"
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_local_smoke_test.dart \
  -d "$TARGET_DEVICE" \
  --dart-define=APP_ENV=local \
  --dart-define=MOBILE_API_BASE_URL="$API_BASE_URL" \
  --dart-define=SMOKE_MEDIA_UPLOADS=true \
  --dart-define=VOICE_SMOKE_MODE="$VOICE_SMOKE_MODE"
