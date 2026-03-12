#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
START_VOICE="${START_VOICE:-1}"
COMPOSE_ENV_ARGS=()

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  COMPOSE_ENV_ARGS=(--env-file "$ENV_FILE")
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed." >&2
  exit 1
fi

POSTGRES_PORT="${POSTGRES_PORT:-5433}"

docker compose "${COMPOSE_ENV_ARGS[@]}" -f "$REPO_ROOT/infra/docker-compose.yml" up -d postgres

if [[ "$START_VOICE" == "1" ]]; then
  docker compose "${COMPOSE_ENV_ARGS[@]}" -f "$REPO_ROOT/infra/docker-compose.voice.yml" up -d
fi

echo "Local support services are ready."
echo "Postgres host port: $POSTGRES_PORT"
if [[ "$START_VOICE" == "1" ]]; then
  echo "Voice stack: enabled"
else
  echo "Voice stack: skipped"
fi
