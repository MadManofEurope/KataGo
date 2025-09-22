#!/usr/bin/env bash
# Fetch a current kata1 "Network File" and verify it before use.
set -euo pipefail

cd "$(dirname "$0")/.."

MODELS_DIR="models"
mkdir -p "${MODELS_DIR}"

URL="${1:-https://katagotraining.org/networks/kata1/}"
echo "Manual step:"
echo "  1. Open ${URL}"
echo "  2. Download the latest 'Network File' (must start with kata1 and end with .bin.gz)"
echo "  3. Place it in ${MODELS_DIR}/ without renaming it"
echo "Reason: site uses dynamic listing; stable direct link not guaranteed."

shopt -s nullglob
networks=("${MODELS_DIR}"/kata1*.bin.gz)
shopt -u nullglob

if [ "${#networks[@]}" -eq 0 ]; then
  echo "No kata1*.bin.gz network found in ${MODELS_DIR}/." >&2
  echo "Download a kata1 network file from ${URL} and try again." >&2
  exit 1
fi

if [ "${#networks[@]}" -gt 1 ]; then
  echo "Multiple kata1 network files detected:" >&2
  printf '  %s\n' "${networks[@]}" >&2
  echo "Keep only one kata1 network in ${MODELS_DIR}/ and re-run this script." >&2
  exit 1
fi

network_path="${networks[0]}"

# Verify gzip integrity without extracting
if ! gzip -t "${network_path}"; then
  echo "Network file ${network_path} failed gzip integrity check." >&2
  echo "Re-download the file; incomplete downloads are not usable." >&2
  exit 1
fi

ln -sf "$(basename "${network_path}")" "${MODELS_DIR}/latest.bin.gz"
echo "Verified $(basename "${network_path}") and linked it as ${MODELS_DIR}/latest.bin.gz"
