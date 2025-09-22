#!/usr/bin/env bash
set -euo pipefail

IMAGE="katago-build:fix"
CONTAINER="kb"

rm -f katago

docker build -f Dockerfile.build -t "${IMAGE}" .

docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
docker create --name "${CONTAINER}" "${IMAGE}"

docker cp "${CONTAINER}:/src/build/katago" ./katago

docker rm "${CONTAINER}"

./katago version
