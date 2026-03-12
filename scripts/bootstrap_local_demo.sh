#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
SERVICES_ONLY=0
SKIP_VOICE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --services-only)
      SERVICES_ONLY=1
      shift
      ;;
    --skip-voice)
      SKIP_VOICE=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: ./scripts/bootstrap_local_demo.sh [--services-only] [--skip-voice]" >&2
      exit 1
      ;;
  esac
done

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

BIND_ADDR="${BIND_ADDR:-0.0.0.0:18080}"
API_PORT="${BIND_ADDR##*:}"
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:${API_PORT}}"

if [[ "$SKIP_VOICE" == "1" ]]; then
  START_VOICE=0 "$REPO_ROOT/scripts/start_local_support_services.sh"
else
  "$REPO_ROOT/scripts/start_local_support_services.sh"
fi

if [[ "$SERVICES_ONLY" == "1" ]]; then
  exit 0
fi

if curl -fsS "$API_BASE_URL/api/v1/health" >/dev/null 2>&1; then
  "$REPO_ROOT/scripts/seed_demo_accounts.sh"
  exit 0
fi

cat <<EOF
Support services are running, but the API server is not reachable at:
  $API_BASE_URL

Next steps:
  1. cargo run -p the_bit_and_bond_server
  2. ./scripts/seed_demo_accounts.sh

Tip:
  Once the server is running, rerun this script to finish demo bootstrap.
EOF
