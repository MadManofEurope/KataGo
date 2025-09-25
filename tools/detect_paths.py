#!/usr/bin/env python3
"""Suggest KaTrain engine settings for the Dockerized KataGo wrapper."""

from __future__ import annotations

from pathlib import Path
from typing import Optional


def find_models_dir() -> Optional[Path]:
    candidates = [
        Path.home() / ".katrain" / "models",
        Path.home() / "KataGo" / "models",
        Path(__file__).resolve().parent.parent / "docker" / "models",
    ]
    for candidate in candidates:
        if candidate.is_dir():
            return candidate.resolve()
    return None


def pick_model_file(models_dir: Path) -> Optional[Path]:
    if not models_dir:
        return None
    for extension in ("*.bin.gz", "*.tgz", "*.gz", "*.zip"):
        for model in models_dir.glob(extension):
            if model.is_file():
                return model.resolve()
    return None


def find_config_file() -> Path:
    repo_cfg = Path(__file__).resolve().parent.parent / "docker" / "example-analysis.cfg"
    if repo_cfg.is_file():
        return repo_cfg.resolve()
    return repo_cfg  # Fallback path even if missing


def main() -> None:
    wrapper_path = Path(__file__).resolve().parent / "katago-docker.sh"
    models_dir = find_models_dir()
    model_file = pick_model_file(models_dir) if models_dir else None
    config_file = find_config_file()

    print("Suggested KaTrain Engine Settings:\n")
    print(f"Path to KataGo executable: {wrapper_path}")

    if model_file is None:
        if models_dir is None:
            print("Warning: No models directory found. Create one (e.g. docker/models/) and download a KataGo model.")
        else:
            print(f"Warning: No model files found in {models_dir}. Download a KataGo model (e.g. kata1-b28c512nbt-s10904468224-d5317014586.bin.gz).")
        model_arg = "/absolute/path/to/your/model.bin.gz"
    else:
        model_arg = str(model_file)

    if not config_file.is_file():
        print(f"Warning: Expected config file {config_file} was not found. Copy docker/example-analysis.cfg to that path or update the argument below.")

    print(
        "Arguments: gtp -model {model} -config {config}".format(
            model=model_arg,
            config=config_file,
        )
    )


if __name__ == "__main__":
    main()
