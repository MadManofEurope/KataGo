#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

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
