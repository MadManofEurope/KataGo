#!/usr/bin/env bash
# Smoke test: send one JSON request; expect JSON reply.
set -euo pipefail
PORT="${KATAGO_PORT:-2388}"

REQ='{"id":"bench1","moves":"","rules":"Chinese","komi":7.5,
"boardXSize":19,"boardYSize":19,"analyzeTurns":[-1],"maxVisits":200}'

printf '%s\n' "$REQ" | nc 127.0.0.1 "$PORT" | head -n 5
