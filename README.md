# KataGo JSON Analysis Service (2.2)

Native KataGo JSON analysis server for Ubuntu 25.04 "Plucky Puffin" hosts with NVIDIA GPUs. The helper scripts download the
official CUDA 12.5 AppImage for KataGo v1.16.3, extract it once to avoid FUSE at runtime, and expose the familiar HTTP JSON API on
port 2388.

## What's new in 2.2

- Native runner: `serve.py` keeps a persistent KataGo analysis subprocess without Docker.
- Idempotent installer: `scripts/native_install_plucky.sh` fetches v1.16.3, extracts the AppImage, and verifies the binary.
- Systemd integration: `systemd/user/katago-json.service` and `scripts/native_enable_service.sh` manage the JSON endpoint as a
  user service.
- Docker workflow is now deprecated in favor of the native runner for Ubuntu 25.04.

## Prerequisites

- Ubuntu 25.04 with Python 3.12+
- NVIDIA GPU driver compatible with CUDA 12.5 (driver 550 or newer is recommended)
- `curl`, `unzip`, and `systemd --user` support

## Quickstart (Native on Ubuntu 25.04)

```bash
git clone -b 2.2 https://github.com/MadManofEurope/KataGo && cd KataGo
./scripts/00_setup_dirs.sh
./scripts/01_get_model.sh
./scripts/native_install_plucky.sh
./scripts/native_run.sh
```

The runner binds to `127.0.0.1:2388` by default. Adjust `KATAGO_CONFIG` to point at a custom configuration file if desired.

### Health check

```bash
curl -fsS http://127.0.0.1:2388 \
  -H 'Content-Type: application/json' \
  -d '{"id":"ping","action":"query_version"}'
```

Successful responses echo the installed KataGo version. To verify the binary without launching the server, run `./serve.py --selftest`.

### Optional: enable as a user service

```bash
./scripts/native_enable_service.sh
systemctl --user status katago-json.service
```

The service runs from `~/KataGo`, restarts automatically, and can be disabled with `systemctl --user disable --now katago-json.service`.

## Configuration and models

- `config/analysis.cfg` is seeded by `scripts/00_setup_dirs.sh` from `config/analysis.cfg.template`. Update it to suit your analysis
  requirements.
- `models/latest.bin.gz` is managed by `scripts/01_get_model.sh`, which downloads the latest kata1 network and refreshes the symlink.
- Set `KATAGO_CONFIG` before starting the runner to override the default configuration path.

## Why extract the AppImage?

KataGo's Linux releases ship as AppImages. Extracting the AppImage at install time removes the runtime FUSE requirement, so the
native runner works on minimal Ubuntu installations without extra kernel modules or elevated privileges.

## References

- [KataGo releases](https://github.com/lightvector/KataGo/releases)
- [Ubuntu 25.04 (Plucky Puffin)](https://discourse.ubuntu.com/t/plucky-puffin-release-notes/)
