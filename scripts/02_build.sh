#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUILDER_DOCKERFILE="docker/Dockerfile.builder"
RUNTIME_DOCKERFILE="docker/Dockerfile.runtime"

if [[ ! -f "${BUILDER_DOCKERFILE}" || ! -f "${RUNTIME_DOCKERFILE}" ]]; then
  cat >&2 <<EOF
Required Dockerfiles were not found.
Expected: ${BUILDER_DOCKERFILE} and ${RUNTIME_DOCKERFILE}.
Ensure the new Dockerfiles are present before running this script.
EOF
  exit 1
fi

GIT_SHA="$(git rev-parse --short HEAD)"
BUILDER_TAG="katago-json-builder:${GIT_SHA}"
RUNTIME_TAG="katago-json:${GIT_SHA}"

declare -a build_args
if [[ -n "${KATAGO_VER:-}" ]]; then
  build_args+=(--build-arg "KATAGO_VER=${KATAGO_VER}")
fi
if [[ -n "${KATAGO_FLAVOR:-}" ]]; then
  build_args+=(--build-arg "KATAGO_FLAVOR=${KATAGO_FLAVOR}")
fi

echo "Building builder image (${BUILDER_TAG})..."
builder_cmd=(docker build -f "${BUILDER_DOCKERFILE}" -t "${BUILDER_TAG}")
builder_cmd+=("${build_args[@]}")
builder_cmd+=(docker)
"${builder_cmd[@]}"

echo "Building runtime image (${RUNTIME_TAG}) using builder stage..."
runtime_cmd=(docker build -f "${RUNTIME_DOCKERFILE}" -t "${RUNTIME_TAG}" --build-arg "BUILDER_IMAGE=${BUILDER_TAG}")
runtime_cmd+=("${build_args[@]}")
runtime_cmd+=(docker)
"${runtime_cmd[@]}"

echo "Runtime image tagged as ${RUNTIME_TAG}"
