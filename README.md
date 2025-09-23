# KataGo JSON Analysis Service (2.1)

Dockerized KataGo JSON analysis server tuned for Ubuntu 24.04 hosts with NVIDIA GPUs. The runtime image is based on
`nvidia/cuda:12.5.1-cudnn-runtime-ubuntu24.04`, downloads the official CUDA 12.5 build of KataGo v1.16.3, and exposes the
JSON API on port 2388.

## What's new in 2.1

- Local-first Docker Compose workflow that always builds the image from source before running.
- Host-mounted configuration respected via `${KATAGO_CONFIG:-/config/analysis.cfg}` so local edits take effect immediately.
- Compose GPU reservation stanza requests all NVIDIA GPUs using the standard `deploy.resources.reservations.devices` block.
- Helper scripts are idempotent and safe to re-run; they create directories, refresh models, rebuild images, and verify the
  JSON endpoint automatically.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose v2](https://docs.docker.com/compose/install/)
- NVIDIA GPU driver compatible with CUDA 12.5 (for example, driver 550 or newer)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Enable GPU access for Compose per Docker's guidance: [Use GPUs with Docker Compose](https://docs.docker.com/compose/gpu-support/)

## Quickstart

```bash
cd KataGo
./scripts/00_setup_dirs.sh            # creates config/ and models/; copies config/analysis.cfg if missing
./scripts/01_get_model.sh              # downloads the newest kata1 network and links models/latest.bin.gz
./scripts/02_build.sh                  # builds katago-json:${GIT_SHA:-local}
./scripts/03_run.sh                    # launches the JSON analysis service and waits for health
curl -fsS http://127.0.0.1:2388 \
  -H 'Content-Type: application/json' \
  -d '{"id":"ping","action":"query_version"}' | python3 -m json.tool
```

The final `curl` command is the same request used by the container healthcheck. Successful responses include the KataGo version
and indicate the GPU-enabled analysis service is ready.

## Configuration and models

- `config/analysis.cfg` is mounted read-only into the container. `scripts/00_setup_dirs.sh` seeds it from
  `config/analysis.cfg.template` if the file is missing. Edit it locally to adjust analysis parameters. The container also forces
  `allowResignation=false` via `-override-config` so KataGo never resigns during analysis sessions.
- `KATAGO_CONFIG` defaults to `/config/analysis.cfg`; override it in `.env` if you mount the config elsewhere.
- Models in `models/` are mounted read-only. The runtime expects `/models/latest.bin.gz`; the helper script maintains this symlink so
  you can keep multiple networks side by side.

## Compose details

`compose.yaml` builds the image locally (`katago-json:${GIT_SHA:-local}`), publishes port `2388`, mounts the configuration and
models directories read-only, and reserves all NVIDIA GPUs using the Compose `deploy.resources.reservations.devices` stanza. The
container healthcheck posts `query_version` to the JSON endpoint to verify readiness.

## References

- [KataGo releases](https://github.com/lightvector/KataGo/releases)
- [CUDA 12.5.1 runtime Ubuntu 24.04 tag](https://hub.docker.com/r/nvidia/cuda/tags?name=12.5.1-runtime-ubuntu24.04)
- [Docker: Use GPUs with Compose](https://docs.docker.com/compose/gpu-support/)
- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
