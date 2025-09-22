#!/usr/bin/env bash
# Probe the KataGo JSON analysis endpoint and validate key fields.
set -euo pipefail

HOST="${KATAGO_HOST:-127.0.0.1}"
PORT="${KATAGO_PORT:-2388}"
TIMEOUT="${KATAGO_PROBE_TIMEOUT:-5}"

REQUEST_PAYLOAD='{"id":"probe","moves":"","rules":"Chinese","komi":7.5,"boardXSize":19,"boardYSize":19,"analyzeTurns":[-1],"maxVisits":64}'

echo "Sending probe request to ${HOST}:${PORT}..."
RESPONSE=$(printf '%s\n' "${REQUEST_PAYLOAD}" | nc -w "${TIMEOUT}" "${HOST}" "${PORT}" | tr -d '\0')

if [[ -z "${RESPONSE}" ]]; then
  echo "No response received from KataGo at ${HOST}:${PORT}." >&2
  exit 1
fi

echo "Validating JSON response..."
printf '%s\n' "${RESPONSE}" | python3 - <<'PY'
import json
import sys

raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit("Empty response received from KataGo.")

payload = None
for line in raw.splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        payload = json.loads(line)
        break
    except json.JSONDecodeError:
        continue

if payload is None:
    raise SystemExit("Unable to parse KataGo response as JSON.")

root = payload.get("rootInfo")
if not isinstance(root, dict):
    raise SystemExit("Response JSON does not contain 'rootInfo'.")

required = ("visits", "edgeVisits", "playSelectionValue")
missing = [key for key in required if key not in root]
if missing:
    raise SystemExit("Missing required fields in rootInfo: " + ", ".join(missing))

summary = {key: root[key] for key in required}
print("Probe OK. rootInfo summary:")
print(json.dumps(summary, indent=2))
PY
