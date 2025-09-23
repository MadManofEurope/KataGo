#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not available, skipping KataGo smoke test." >&2
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin not available, skipping KataGo smoke test." >&2
  exit 0
fi

cleanup() {
  docker compose down -v
}
trap cleanup EXIT

payload='{"id":"ping","action":"query_version"}'

# Rebuild image without cache to ensure Dockerfile changes are respected
docker compose build --no-cache

docker compose up -d

endpoint="http://127.0.0.1:2388"
start_time=$(date +%s)

while true; do
  if curl -fsS "${endpoint}" \
    -H 'Content-Type: application/json' \
    -d "${payload}" >/dev/null; then
    break
  fi

  if (( $(date +%s) - start_time >= 60 )); then
    echo "KataGo JSON API did not become ready within 60 seconds" >&2
    docker compose logs --no-color katago | tail -n 200
    exit 1
  fi

  sleep 2
done

echo "KataGo JSON API responded successfully"
