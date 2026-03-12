#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "[rust] cargo fmt --all --check"
cargo fmt --all --check

echo "[rust] cargo clippy -p the_bit_and_bond_server -- -D warnings"
cargo clippy -p the_bit_and_bond_server -- -D warnings

echo "[rust] cargo test -p the_bit_and_bond_server --locked"
cargo test -p the_bit_and_bond_server --locked

echo "[contract] python3 scripts/check_openapi_routes.py"
python3 scripts/check_openapi_routes.py

echo "[flutter] flutter analyze"
(
  cd apps/client_flutter
  flutter analyze
)

echo "[flutter] flutter test"
(
  cd apps/client_flutter
  flutter test
)

echo "[flutter] dart run tool/check_hardcoded_strings.dart --check"
(
  cd apps/client_flutter
  dart run tool/check_hardcoded_strings.dart --check
)

echo "All quality gates passed."
