#!/usr/bin/env bash
# Smoke test: send one JSON request; expect JSON reply.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"
PORT="${KATAGO_PORT:-2388}"

REQ='{"id":"bench1","action":"query_version"}'

if command -v curl >/dev/null 2>&1; then
  curl -s http://127.0.0.1:"$PORT" \
    -H 'Content-Type: application/json' \
    -d "$REQ" | python3 -m json.tool
else
  printf '%s\n' "$REQ" | nc 127.0.0.1 "$PORT" | head -n 5
fi
