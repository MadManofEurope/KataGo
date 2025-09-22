#!/usr/bin/env bash
# Fetch the latest kata1 "Network File" automatically and verify it.
set -euo pipefail

cd "$(dirname "$0")/.."

MODELS_DIR="models"
mkdir -p "${MODELS_DIR}"

NETWORK_PAGE_URL="${KATAGO_NETWORK_PAGE_URL:-https://katagotraining.org/networks/kata1/}"
TARGET_PATH="${MODELS_DIR}/latest.bin.gz"

tmp_html="$(mktemp)"
tmp_download="$(mktemp)"
cleanup() {
  rm -f "${tmp_html}" "${tmp_download}"
}
trap cleanup EXIT

echo "Fetching kata1 network list from ${NETWORK_PAGE_URL}..."
if ! curl -fsSL "${NETWORK_PAGE_URL}" -o "${tmp_html}"; then
  echo "Failed to download network index from ${NETWORK_PAGE_URL}." >&2
  exit 1
fi

download_url="$(python3 - "$tmp_html" "$NETWORK_PAGE_URL" <<'PY'
import sys
from html.parser import HTMLParser
from urllib.parse import urljoin

page_path, base_url = sys.argv[1:3]

class NetworkLinkParser(HTMLParser):
    def __init__(self, base):
        super().__init__()
        self.base = base
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        href = dict(attrs).get("href")
        if not href:
            return
        if not href.endswith(".bin.gz") or "kata1" not in href:
            return
        self.links.append(urljoin(self.base, href))

parser = NetworkLinkParser(base_url)
with open(page_path, "r", encoding="utf-8") as f:
    parser.feed(f.read())

if not parser.links:
    sys.exit(1)

print(parser.links[0])
PY
)"

if [[ -z "${download_url}" ]]; then
  echo "Could not locate a kata1 network download link on the index page." >&2
  exit 1
fi

echo "Downloading latest kata1 network..."
if ! curl -fL "${download_url}" -o "${tmp_download}"; then
  echo "Failed to download kata1 network from ${download_url}." >&2
  exit 1
fi

if ! gzip -t "${tmp_download}"; then
  echo "Downloaded network failed gzip integrity check." >&2
  exit 1
fi

mv "${tmp_download}" "${TARGET_PATH}"
echo "Saved $(basename "${download_url}") to ${TARGET_PATH}" \
  "($(du -h "${TARGET_PATH}" | awk '{print $1}'))"
