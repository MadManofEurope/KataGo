#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  docker compose down -v
}
trap cleanup EXIT

payload='{"id":"ping","action":"query_version"}'

docker compose build
docker compose up -d

endpoint="http://127.0.0.1:2388"
deadline=$((SECONDS + 60))

while (( SECONDS < deadline )); do
  if curl -fsS "${endpoint}" \
    -H 'Content-Type: application/json' \
    -d "${payload}" >/dev/null; then
    echo "KataGo JSON API responded successfully"
    exit 0
  fi
  sleep 2
done

echo "KataGo JSON API did not become ready within 60 seconds" >&2
docker compose logs --no-color katago | tail -n 200 || true
exit 1
