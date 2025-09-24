# KataGo JSON Analysis Service (2.3)

Native KataGo JSON analysis server for Ubuntu 25.04 "Plucky Puffin" hosts with NVIDIA GPUs. The helper scripts now download
the upstream KataGo v1.16.3 CUDA 12.8 AppImage by default, wrap it with a stable `.bin/katago` launcher, and expose the
familiar HTTP JSON API on port 2388.

## What's new in 2.3

- Native bootstrap scripts prefer the upstream AppImage to avoid host `libzip` mismatches and seed `config/analysis.cfg`
  during installation.
- `serve.py --selftest` verifies the binary, config, and model paths before running a `query_version` probe.
- GitHub Actions workflow exercises the bootstrap path with a mocked KataGo binary.

## Prerequisites

- Ubuntu 25.04 with Python 3.12+
- NVIDIA GPU driver compatible with CUDA 12.x (CUDA 12.8 preferred; driver 550 or newer is recommended)
- `curl`, `jq`, `unzip`, and `systemd --user` support
- Optional: `GITHUB_TOKEN` to raise GitHub API rate limits when auto-discovering assets

## Quickstart (Native on Ubuntu 25.04)

```bash
git clone -b 2.3 https://github.com/MadManofEurope/KataGo && cd KataGo && ./scripts/bootstrap.sh
```

`bootstrap.sh` verifies the checkout, installs the KataGo AppImage to sidestep host `libzip` requirements, downloads a kata1 network, and launches the JSON service bound to `127.0.0.1:2388`. Re-run it at any time to repair dependencies and restart the server.

### Optional: ZIP binary (advanced)

The installer falls back to the CUDA 12.x ZIP release if the AppImage download fails or the host lacks a working NVIDIA GPU. The ZIP build depends on `libzip.so.4`; if the system loader reports that dependency as missing, rerun `./scripts/native_install.sh` to fetch the AppImage instead.

### Health check

```bash
curl -fsS http://127.0.0.1:2388/query \
  -H 'Content-Type: application/json' \
  -d '{"id":"ping","action":"query_version"}'
```

Successful responses echo the installed KataGo version. To verify the binary without launching the server, run:

```bash
python3 serve.py --selftest
```

The self-test auto-detects the default `.bin/katago`, `models/latest.bin.gz`, and `config/analysis.cfg` paths. If any asset is missing it exits with status 2 and prints which script to run (`./scripts/native_install.sh` for the binary/config or `./scripts/01_get_model.sh` for the model).

### CI/testing shortcuts

- `CI_MOCK_ENGINE=1 ./scripts/native_install.sh` replaces the real AppImage with a tiny Python stub that implements
  `--version` and responds to `analysis` requests. This keeps CI fast and GPU-free.
- `CI_MOCK_MODEL=1 ./scripts/01_get_model.sh` generates a 1-line gzip placeholder and refreshes `models/latest.bin.gz` without
  downloading the full kata1 network.

### Optional: enable as a user service

```bash
./scripts/native_enable_service.sh
systemctl --user status katago-json.service
```

The service runs from `~/KataGo`, restarts automatically, and can be disabled with `systemctl --user disable --now katago-json.service`.

## Troubleshooting

- `fatal: destination path 'KataGo' already exists and is not an empty directory.` → Move or delete the existing `~/KataGo` folder (or clone elsewhere), then rerun the Quickstart command.
- `./scripts/native_install.sh: not found` or `./scripts/native_run.sh: not found` → Run `./scripts/check_tree.sh` and follow the printed `git fetch origin && git switch -C 2.3 origin/2.3` instruction to refresh the checkout.
- `curl 127.0.0.1:2388/query: connection refused` → Start the server with `./scripts/bootstrap.sh` (or rerun it to restart the service).
- `python3 serve.py --selftest` reports missing files → Rerun the script named in the message (`native_install.sh` for the binary/config or `01_get_model.sh` for the model) and run the self-test again.
- `systemctl --user status katago-json.service: Unit katago-json.service not found.` → Enable the user service with `./scripts/native_enable_service.sh` before checking the status.
- `error while loading shared libraries: libzip.so.4` → The ZIP binary is missing a dependency. Re-run `./scripts/native_install.sh` to download the AppImage instead.

## Configuration and models

- `config/analysis.cfg` is seeded by `scripts/native_install.sh` from `config/analysis.cfg.template`. Update it to suit your analysis
  requirements.
- `models/latest.bin.gz` is managed by `scripts/01_get_model.sh`, which downloads a kata1 network if none exist, validates gzip integrity, and refreshes the symlink. Set `KATAGO_MODEL_URL` to override the default download URL. Use `CI_MOCK_MODEL=1` to generate a tiny placeholder network for CI or test environments.
- Set `KATAGO_CONFIG` before starting the runner to override the default configuration path.

## Why ship the AppImage?

Ubuntu 25.04 no longer provides `libzip.so.4`, which the legacy ZIP builds require. Running the upstream AppImage keeps the CUDA 12.8 binary self-contained, bypasses host `libzip` issues, and avoids Docker entirely.

## References

- [KataGo releases](https://github.com/lightvector/KataGo/releases)
- [Ubuntu 25.04 (Plucky Puffin)](https://discourse.ubuntu.com/t/plucky-puffin-release-notes/)
