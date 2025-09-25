#!/usr/bin/env bash
set -euo pipefail

KATAGO_IMAGE="${KATAGO_IMAGE:-lightvector/katago:latest-cuda}"

if ! command -v docker >/dev/null 2>&1; then
  printf 'Error: Docker is not installed or not on your PATH. Install Docker Engine before using this wrapper.\n' >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  printf 'Error: Docker daemon does not appear to be running. Start Docker and try again.\n' >&2
  exit 1
fi

declare -A ADDED_VOLUMES=()
declare -a VOLUMES=()

add_volume() {
  local path="$1"
  if [[ -z "$path" ]]; then
    return
  fi
  if [[ ! "$path" = /* ]]; then
    printf 'Warning: Skipping non-absolute path "%s". Provide absolute paths in KaTrain.\n' "$path" >&2
    return
  fi
  local dir
  dir=$(dirname "$path")
  if [[ -z "$dir" || "$dir" == "." ]]; then
    dir="$path"
  fi
  if [[ -z "${ADDED_VOLUMES[$dir]:-}" ]]; then
    if [[ ! -d "$dir" ]]; then
      printf 'Warning: Directory "%s" does not exist on the host. Ensure the path is correct.\n' "$dir" >&2
    fi
    VOLUMES+=(-v "$dir:$dir:ro")
    ADDED_VOLUMES[$dir]=1
  fi
}

collect_path_arg() {
  local value="$1"
  add_volume "$value"
}

ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
  arg="${ARGS[$i]}"
  case "$arg" in
    -model|-config|-analysisconfig|-cfg|--model|--config|--analysisconfig|--cfg)
      if (( i + 1 < ${#ARGS[@]} )); then
        collect_path_arg "${ARGS[$((i+1))]}"
        ((i++))
      fi
      ;;
    -model=*|-config=*|-analysisconfig=*|-cfg=*|--model=*|--config=*|--analysisconfig=*|--cfg=*)
      collect_path_arg "${arg#*=}"
      ;;
  esac
done

cwd=$(pwd)
if [[ -z "${ADDED_VOLUMES[$cwd]:-}" ]]; then
  VOLUMES+=(-v "$cwd:$cwd")
  ADDED_VOLUMES[$cwd]=1
fi

set +e
docker run --rm --gpus all "${VOLUMES[@]}" "$KATAGO_IMAGE" katago "$@"
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
  if [[ $STATUS -eq 125 ]]; then
    printf 'Error: Docker failed to start the container. Ensure the image "%s" exists (docker pull %s) and that the NVIDIA Container Toolkit is installed for GPU support.\n' "$KATAGO_IMAGE" "$KATAGO_IMAGE" >&2
  else
    printf 'Error: Docker exited with status %d. Inspect the message above for details.\n' "$STATUS" >&2
  fi
  exit $STATUS
fi
