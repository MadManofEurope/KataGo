#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PORT="${PORT:-2388}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-180}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to probe the KataGo JSON endpoint." >&2
  exit 1
fi

docker compose up -d

deadline=$((SECONDS + HEALTH_TIMEOUT))

printf 'Waiting for KataGo JSON service to become healthy'
while (( SECONDS < deadline )); do
  if curl -fsS -X POST "http://127.0.0.1:${PORT}" \
    -H 'Content-Type: application/json' \
    -d '{"id":"ping","action":"query_version"}' >/dev/null; then
    echo " - healthy"
    docker compose ps
    exit 0
  fi
  printf '.'
  sleep 3
done

printf '\nTimed out waiting for KataGo JSON service to become healthy.\n' >&2
docker compose logs --tail 50 >&2
exit 1
