#!/usr/bin/env bash
set -euo pipefail

print_section() {
  printf '\n%s\n' "$1"
}

print_version() {
  local cmd="$1"
  shift
  local args=("$@")
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%s version:\n' "$cmd"
    "$cmd" "${args[@]}"
  else
    printf 'Warning: %s not found in PATH.\n' "$cmd"
  fi
}

print_section "Checking required commands"
print_version nvidia-smi
print_version docker --version
if command -v nvidia-ctk >/dev/null 2>&1; then
  print_version nvidia-ctk --version
else
  printf 'nvidia-ctk not found. Install the NVIDIA Container Toolkit if you plan to use Docker with GPUs.\n'
fi

if ! command -v docker >/dev/null 2>&1; then
  printf '\nError: Docker is required but was not found. Install Docker Engine and ensure it is available on your PATH.\n'
  exit 1
fi

print_section "Running CUDA base container GPU test"

set +e
TEST_OUTPUT=$(docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi 2>&1)
STATUS=$?
set -e

printf '%s\n' "$TEST_OUTPUT"

if [[ $STATUS -ne 0 ]]; then
  if [[ "$TEST_OUTPUT" == *"unknown flag: --gpus"* ]]; then
    printf '\nError: Docker does not recognize --gpus. Install and configure the NVIDIA Container Toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) and ensure Docker uses the NVIDIA runtime.\n'
  else
    printf '\nError: Docker GPU test failed. Review the output above for details.\n'
  fi
  exit $STATUS
fi

if ! grep -q "NVIDIA-SMI" <<<"$TEST_OUTPUT"; then
  printf '\nError: GPU was not visible inside the container. Ensure the NVIDIA drivers are installed, the GPU is not in use by another process, and that the NVIDIA Container Toolkit is configured.\n'
  exit 1
fi

printf '\nSuccess: GPU is accessible inside Docker.\n'
