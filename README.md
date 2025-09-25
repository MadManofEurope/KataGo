# KataGo JSON Analysis Service (2.6)

Dockerized KataGo JSON analysis server tuned for NVIDIA GPUs. The runtime image is based on
`nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04`, downloads the official CUDA 12.1 + cuDNN 8.9.7 build of KataGo v1.16.3, and
exposes the JSON API on port 2388. The KataGo AppImage is extracted during the Docker build so the runtime container never
requires FUSE support. HTTP remains the default mode, and the image now exposes KataGo's stdin/stdout JSON analysis engine for
KaTrain and other desktop clients.

## What's new in 2.6

- Base image pinned to `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04` to match the CUDA 12.1 + cuDNN 8.9.7 KataGo asset.
- Runtime symlinks `/usr/local/bin/katago` to the AppImage launcher for both HTTP and stdin workflows.
- `KATAGO_MODE=stdin` execs KataGo's JSON analysis engine directly; HTTP remains the default when unset.
- Config template removes play-only keys, adds threading hints, and defaults to `numSearchThreadsPerAnalysisThread`.
- `scripts/04_ci_smoke.sh` runs a local stdin smoke test, and `scripts/05_print_katrain_cmd.sh` prints the KaTrain override line.
- Documentation covers the single-terminal setup flow, GPU guidance, KaTrain override, and Kivy audio freeze workaround.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose v2](https://docs.docker.com/compose/install/)
- NVIDIA GPU driver compatible with CUDA 12.1 (for example, driver 530 or newer)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Enable GPU access for Compose per Docker's guidance: [Use GPUs with Docker Compose](https://docs.docker.com/compose/gpu-support/)

## Single-terminal Quickstart

```bash
git clone --branch 2.6 https://github.com/MadManofEurope/KataGo.git ~/KataGo
cd ~/KataGo
./scripts/00_setup_dirs.sh
./scripts/01_get_model.sh
./scripts/02_build.sh
./scripts/04_ci_smoke.sh katago-json:$(git rev-parse --short HEAD)
./scripts/05_print_katrain_cmd.sh   # copy the ONE line into KaTrain -> Override engine command
```

> **KaTrain note:** KaTrain uses KataGo's JSON analysis engine over stdin/stdout. Use the printed one-liner; do not use the HTTP port.

`scripts/04_ci_smoke.sh` uses `docker run --gpus all` with the stdin engine to verify the image, config, and model locally. The
smoke test prints a single JSON line containing the KataGo version. `scripts/05_print_katrain_cmd.sh` outputs a ready-to-paste
Docker command that KaTrain can run without edits.

## Configuration

- `config/analysis.cfg` is mounted read-only into the container. `scripts/00_setup_dirs.sh` seeds it from
  `config/analysis.cfg.template` if the file is missing. Edit it locally to adjust analysis parameters. The template includes
  tuning hints for balancing GPU batch size and thread counts.
- `KATAGO_CONFIG` defaults to `/config/analysis.cfg`; override it in `.env` if you mount the config elsewhere.

## Models

- Place a local network such as `kata1-b28c512nbt-s10904468224-d5317014586.bin.gz` under `models/`, then run:

  ```bash
  ./scripts/01_get_model.sh --file ./models/kata1-b28c512nbt-s10904468224-d5317014586.bin.gz
  ```

  The script validates the `.bin.gz` file, prints its resolved path and SHA-256 checksum, and links it as `models/latest.bin.gz`.
- Alternatively, omit `--file` (or the `MODEL_FILE` environment variable) to download the newest `kata1` network:

  ```bash
  ./scripts/01_get_model.sh
  ```

  The helper downloads the most recent network, verifies gzip integrity, and refreshes the `models/latest.bin.gz` symlink.

## GPU access

When running the container manually, request GPU access explicitly:

```bash
docker run --rm -i --gpus all \
  -v "$PWD/config:/config:ro" -v "$PWD/models:/models:ro" \
  --entrypoint /usr/local/bin/katago katago-json:local \
  analysis -config /config/analysis.cfg -model /models/latest.bin.gz
```

The example mirrors `scripts/04_ci_smoke.sh`. For Compose deployments, use the standard device reservation stanza (Docker will
forward the request to the NVIDIA Container Toolkit):

```yaml
services:
  katago:
    image: katago-json:${TAG}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      - KATAGO_MODE=http
```

## No host cuDNN

Do **not** install `cudnn-local-repo-ubuntu2204-8.9.7.29_1.0-1_amd64.deb` or any other host-level cuDNN packages. The container
image `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04` already bundles cuDNN, and the entrypoint logs a warning if `libcudnn` is
unexpectedly missing from `ldconfig -p` output.

## Troubleshooting

- If the Docker build fails immediately at the `FROM` instruction, verify that `nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04`
  still exists on Docker Hub and adjust the tag if NVIDIA republishes it under a different name.
- KaTrain on Python 3.13 + Kivy 2.3.1 can freeze after placing a stone if SDL2 audio is enabled. Set `KIVY_AUDIO=ffpyplayer` or
  pin Kivy below 2.3.1. See the [Kivy environment variables reference](https://kivy.org/doc/stable/guide/environment.html) for
  more details.

## References

- [KataGo releases](https://github.com/lightvector/KataGo/releases)
- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [Docker: Use GPUs with Compose](https://docs.docker.com/compose/gpu-support/)
- [KaTrain](https://github.com/sanderland/katrain)
- [Kivy environment variables](https://kivy.org/doc/stable/guide/environment.html)
