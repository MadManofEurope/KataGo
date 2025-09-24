#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

required_paths=(
  "scripts/native_install.sh"
  "scripts/native_run.sh"
  "serve.py"
  "config/analysis.cfg.template"
)

missing=()
for rel_path in "${required_paths[@]}"; do
  if [[ ! -e "${ROOT_DIR}/${rel_path}" ]]; then
    missing+=("${rel_path}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Detected stale checkout missing: %s\n' "${missing[*]}" >&2
  echo 'git fetch origin && git switch -C 2.3 origin/2.3' >&2
  exit 3
fi
