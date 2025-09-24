#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/check_tree.sh
source "${SCRIPT_DIR}/check_tree.sh"

SUMMARY=""
FAILED=0
CONFIG_TMP=""
COMPOSE_BIN=()
NETCAT_IMPL=""

record() {
  local status="$1"
  local name="$2"
  local hint="${3:-}"
  SUMMARY+="${status}: ${name}"
  if [ -n "$hint" ]; then
    SUMMARY+=" — ${hint}"
  fi
  SUMMARY+="\n"
  if [ "$status" = "FAIL" ]; then
    FAILED=1
  fi
}

print_summary() {
  local exit_code="$1"
  if [ -n "$CONFIG_TMP" ] && [ -f "$CONFIG_TMP" ]; then
    rm -f "$CONFIG_TMP"
  fi
  printf '\nSummary:\n'
  printf '%s' "$SUMMARY"
  if [ "$FAILED" -ne 0 ] && [ "$exit_code" -eq 0 ]; then
    exit_code=$FAILED
  fi
  exit "$exit_code"
}
trap 'print_summary $?' EXIT

log() {
  printf '==> %s\n' "$*"
}

# Tool checks
if command -v docker >/dev/null 2>&1; then
  log "Docker version: $(docker --version)"
else
  record FAIL "Docker CLI" "Install Docker from https://docs.docker.com/engine/install/"
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN=(docker compose)
  log "Docker Compose version: $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BIN=(docker-compose)
  log "Docker Compose version: $(docker-compose version)"
else
  record FAIL "Docker Compose" "Install Docker Compose per https://docs.docker.com/compose/install/"
  exit 1
fi

if command -v nc >/dev/null 2>&1; then
  NETCAT_IMPL="nc"
  log "Netcat present: $(nc -h 2>&1 | head -n1)"
elif command -v ncat >/dev/null 2>&1; then
  NETCAT_IMPL="ncat"
  log "Ncat present: $(ncat --version 2>&1 | head -n1)"
elif command -v socat >/dev/null 2>&1; then
  NETCAT_IMPL="socat"
  log "Socat present: $(socat -V 2>&1 | head -n1)"
else
  record FAIL "Socket client" "Install nc (netcat) or socat to send health probes"
fi

if [ -n "$NETCAT_IMPL" ]; then
  record PASS "Tooling" "docker, docker compose, and socket client detected"
else
  record FAIL "Tooling" "Install nc or socat to enable health probe"
  exit 1
fi

# Compose validity
CONFIG_TMP=$(mktemp)
if "${COMPOSE_BIN[@]}" config >"$CONFIG_TMP"; then
  log "docker compose config succeeded"
  record PASS "Compose config" "Validated by docker compose config"
else
  record FAIL "Compose config" "Invalid YAML → fix services: and syntax."
  exit 1
fi

if grep -q '^services:' "$CONFIG_TMP"; then
  record PASS "Compose services" "services: section detected"
else
  record FAIL "Compose services" "Invalid YAML → fix services: and syntax."
fi

# Image buildability
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^katago-json:'; then
  log "Found existing katago-json image"
else
  log "No local katago-json image found; running docker compose build --no-cache"
  if "${COMPOSE_BIN[@]}" build --no-cache; then
    log "docker compose build completed"
  else
    record FAIL "Image build" "No build section → add build: to service."
    exit 1
  fi
fi

if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q '^katago-json:'; then
  record PASS "Image presence" "katago-json image available"
else
  record FAIL "Image presence" "No build section → add build: to service."
fi

# Host NVIDIA checks
if command -v nvidia-smi >/dev/null 2>&1; then
  log "nvidia-smi output:" 
  nvidia-smi | sed 's/^/    /'
  record PASS "Host NVIDIA driver" "nvidia-smi detected"
else
  record FAIL "Host NVIDIA driver" "Install NVIDIA drivers and toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)"
fi

log "docker info NVIDIA snippets:"
docker info 2>/dev/null | grep -i nvidia || true

# Model and config presence
if [ -f models/latest.bin.gz ]; then
  record PASS "Model file" "./models/latest.bin.gz present"
else
  record FAIL "Model file" "Download KataGo network into ./models/latest.bin.gz"
fi

if [ -f config/analysis.cfg ]; then
  record PASS "Analysis config" "./config/analysis.cfg present"
else
  record FAIL "Analysis config" "Provide ./config/analysis.cfg"
fi

if grep -q 'KATAGO_CONFIG' entrypoint.sh; then
  record PASS "Entrypoint config" "entrypoint.sh honors KATAGO_CONFIG"
elif grep -q '/config/analysis.cfg' entrypoint.sh; then
  record FAIL "Entrypoint config" "Config ignored → update entrypoint to honor KATAGO_CONFIG."
else
  record FAIL "Entrypoint config" "Config ignored → update entrypoint to honor KATAGO_CONFIG."
fi

# Compose GPU reservation check
if grep -Eq 'driver:[[:space:]]*nvidia' "$CONFIG_TMP" && grep -Eq 'capabilities:[[:space:]]*\[[^]]*gpu[^]]*\]' "$CONFIG_TMP"; then
  record PASS "GPU reservation" "Compose config includes NVIDIA GPU reservation"
else
  record FAIL "GPU reservation" "No GPU in container → install NVIDIA Container Toolkit and use Compose GPU reservations."
fi

# Bring up the service
if "${COMPOSE_BIN[@]}" up -d; then
  record PASS "Compose up" "Services started in background"
else
  record FAIL "Compose up" "docker compose up failed"
  exit 1
fi

PORT="${KATAGO_PORT:-2388}"
if ss -ltn | grep -F ":${PORT} " | grep -q "127.0.0.1"; then
  record PASS "Port binding" "Port ${PORT} bound to 127.0.0.1"
else
  record FAIL "Port binding" "Ensure docker compose ports map to 127.0.0.1:${PORT}"
fi

# NVIDIA inside container
GPU_HINT="No GPU in container → install NVIDIA Container Toolkit and use Compose GPU reservations."
if "${COMPOSE_BIN[@]}" ps -q katago >/dev/null 2>&1; then
  if "${COMPOSE_BIN[@]}" exec -T katago nvidia-smi >/dev/null 2>&1; then
    log "Container nvidia-smi output:"
    "${COMPOSE_BIN[@]}" exec -T katago nvidia-smi | head -n 15
    record PASS "Container NVIDIA" "nvidia-smi available inside container"
  else
    record FAIL "Container NVIDIA" "$GPU_HINT"
  fi
else
  record FAIL "Container NVIDIA" "Service not running"
fi

# Health probe
REQ='{"id":"screen","moves":"","rules":"Chinese","komi":7.5,"boardXSize":19,"boardYSize":19,"analyzeTurns":[-1],"maxVisits":32}'
RESPONSE=""
case "$NETCAT_IMPL" in
  nc|ncat)
    if RESPONSE=$(printf '%s\n' "$REQ" | "$NETCAT_IMPL" 127.0.0.1 "$PORT" | head -n1); then
      :
    else
      RESPONSE=""
    fi
    ;;
  socat)
    if RESPONSE=$(printf '%s\n' "$REQ" | socat - TCP:127.0.0.1:"$PORT",connect-timeout=5 2>/dev/null | head -n1); then
      :
    else
      RESPONSE=""
    fi
    ;;
esac

if [ -n "$RESPONSE" ]; then
  log "Health probe reply: $RESPONSE"
  record PASS "Health probe" "katago analysis replied"
else
  record FAIL "Health probe" "Ensure katago analysis engine runs: ./katago analysis -config CFG -model NET"
fi
