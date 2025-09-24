#!/usr/bin/env python3
"""Expose KataGo's JSON analysis engine over HTTP."""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import threading
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import List, Optional


REPO_ROOT = Path(__file__).resolve().parent
INSTALL_COMMAND = "./scripts/native_install.sh"
MODEL_COMMAND = "./scripts/01_get_model.sh"


def resolve_default(env_name: str, fallback: str) -> Path:
    value = os.environ.get(env_name)
    if value:
        candidate = Path(os.path.expanduser(value))
    else:
        candidate = Path(os.path.expanduser(fallback))
    if not candidate.is_absolute():
        candidate = REPO_ROOT / candidate
    return candidate


@dataclass
class EngineConfig:
    katago: Path
    model: Path
    config: Path


class KataGoEngine:
    """Manage a persistent KataGo analysis subprocess."""

    def __init__(self, cfg: EngineConfig) -> None:
        self._cfg = cfg
        self._lock = threading.Lock()
        self._proc = self._launch()

    def _launch(self) -> subprocess.Popen:
        cmd = [
            str(self._cfg.katago),
            "analysis",
            "-model",
            str(self._cfg.model),
            "-config",
            str(self._cfg.config),
        ]
        return subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            text=True,
            bufsize=1,
        )

    def terminate(self) -> None:
        proc = self._proc
        if proc.poll() is not None:
            return
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)

    def query(self, payload: Dict[str, object]) -> str:
        text = json.dumps(payload, separators=(",", ":")) + "\n"
        with self._lock:
            proc = self._proc
            if proc.poll() is not None:
                raise RuntimeError("KataGo engine has exited unexpectedly.")
            assert proc.stdin is not None
            assert proc.stdout is not None
            proc.stdin.write(text)
            proc.stdin.flush()
            request_id = payload.get("id") if isinstance(payload, dict) else None
            lines: list[str] = []
            while True:
                line = proc.stdout.readline()
                if not line:
                    raise RuntimeError("KataGo produced no response and may have exited.")
                lines.append(line)
                try:
                    parsed = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(parsed, dict):
                    if "error" in parsed:
                        break
                    parsed_id = parsed.get("id")
                    is_alive = parsed.get("isAlive")
                    if request_id is None:
                        if is_alive is False:
                            break
                        if "isAlive" not in parsed:
                            break
                    else:
                        if parsed_id == request_id and is_alive is False:
                            break
                        if parsed_id == request_id and "isAlive" not in parsed:
                            break
            return "".join(lines)


class KataGoRequestHandler(BaseHTTPRequestHandler):
    engine: KataGoEngine  # Injected at server startup.

    def do_POST(self) -> None:  # noqa: N802 - inherited
        if self.path != "/query":
            self._send_error(HTTPStatus.NOT_FOUND, "Only /query is supported")
            return
        content_length = self.headers.get("Content-Length")
        if content_length is None:
            self._send_error(HTTPStatus.LENGTH_REQUIRED, "Missing Content-Length header")
            return
        try:
            length = int(content_length)
        except ValueError:
            self._send_error(HTTPStatus.BAD_REQUEST, "Invalid Content-Length header")
            return
        body = self.rfile.read(length)
        if not body:
            self._send_error(HTTPStatus.BAD_REQUEST, "Empty request body")
            return
        try:
            payload = json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_error(HTTPStatus.BAD_REQUEST, "Body must be valid JSON")
            return
        if not isinstance(payload, dict):
            self._send_error(HTTPStatus.BAD_REQUEST, "Body must be a JSON object")
            return
        try:
            response_text = self.engine.query(payload)
        except FileNotFoundError as exc:
            self._send_error(HTTPStatus.SERVICE_UNAVAILABLE, str(exc))
            return
        except Exception as exc:  # noqa: BLE001 - surface engine failures
            self._send_error(HTTPStatus.BAD_GATEWAY, f"KataGo query failed: {exc}")
            return
        response_bytes = response_text.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response_bytes)))
        self.end_headers()
        self.wfile.write(response_bytes)

    def do_GET(self) -> None:  # noqa: N802 - inherited
        self._send_error(HTTPStatus.METHOD_NOT_ALLOWED, "Use POST /query")

    def log_message(self, format: str, *args: object) -> None:  # noqa: A003 - match BaseHTTPRequestHandler
        sys.stderr.write("[serve.py] " + (format % args) + "\n")

    def _send_error(self, status: HTTPStatus, message: str) -> None:
        body = json.dumps({"error": message, "status": status.value})
        data = body.encode("utf-8")
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def parse_args() -> argparse.Namespace:
    katago_default = resolve_default("KATAGO", ".bin/katago")
    model_default = resolve_default("MODEL", "models/latest.bin.gz")
    config_default = resolve_default("KATAGO_CONFIG", "config/analysis.cfg")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=2388)
    parser.add_argument(
        "--katago",
        type=Path,
        default=None,
        help=f"Path to the KataGo binary (default: {katago_default})",
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=None,
        help=f"Path to the KataGo model file (default: {model_default})",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=None,
        help=f"Path to KataGo analysis config (default: {config_default})",
    )
    parser.add_argument("--selftest", action="store_true", help="Run a query_version check and exit")
    return parser.parse_args()


def run_server(args: argparse.Namespace, engine: KataGoEngine) -> None:
    handler_cls = KataGoRequestHandler
    handler_cls.engine = engine
    server = ThreadingHTTPServer((args.host, args.port), handler_cls)
    server.daemon_threads = True

    def shutdown(_signum: int, _frame: Optional[object]) -> None:
        server.shutdown()

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)
    try:
        server.serve_forever()
    finally:
        engine.terminate()
        server.server_close()


def resolve_path_argument(arg: Optional[Path], env_name: str, fallback: str) -> Path:
    if arg is not None:
        return Path(os.path.expanduser(str(arg)))
    return resolve_default(env_name, fallback)


def collect_environment_errors(katago: Path, model: Path, config: Path) -> List[str]:
    errors: List[str] = []
    if not katago.exists():
        errors.append(
            f"Missing KataGo binary at {katago}. Run {INSTALL_COMMAND} to install it."
        )
    elif katago.is_dir():
        errors.append(
            f"Expected a KataGo executable at {katago}, but found a directory. Remove it and run {INSTALL_COMMAND}."
        )
    elif not os.access(katago, os.X_OK):
        errors.append(
            f"KataGo binary at {katago} is not executable. Re-run {INSTALL_COMMAND}."
        )
    if not model.exists():
        errors.append(
            f"Missing model file at {model}. Run {MODEL_COMMAND} after {INSTALL_COMMAND}."
        )
    elif not model.is_file():
        errors.append(
            f"KataGo model at {model} is not a regular file. Re-run {MODEL_COMMAND} after {INSTALL_COMMAND}."
        )
    elif not os.access(model, os.R_OK):
        errors.append(
            f"KataGo model at {model} is not readable. Fix permissions or rerun {MODEL_COMMAND}."
        )
    if not config.exists():
        errors.append(
            f"Missing config file at {config}. Run {INSTALL_COMMAND} to generate it."
        )
    elif not config.is_file():
        errors.append(
            f"Expected a config file at {config}. Run {INSTALL_COMMAND} to restore it."
        )
    elif not os.access(config, os.R_OK):
        errors.append(
            f"Config file at {config} is not readable. Fix permissions or rerun {INSTALL_COMMAND}."
        )
    return errors


def print_environment_errors(errors: List[str]) -> None:
    for msg in errors:
        print(msg, file=sys.stderr)


def launch_engine(cfg: EngineConfig) -> Optional[KataGoEngine]:
    try:
        return KataGoEngine(cfg)
    except (FileNotFoundError, PermissionError) as exc:
        print(f"Failed to launch KataGo: {exc}", file=sys.stderr)
        return None
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to launch KataGo: {exc}", file=sys.stderr)
        return None


def ensure_environment(cfg: EngineConfig) -> bool:
    errors = collect_environment_errors(cfg.katago, cfg.model, cfg.config)
    if errors:
        print_environment_errors(errors)
        return False
    return True


def run_selftest(cfg: EngineConfig) -> int:
    errors = collect_environment_errors(cfg.katago, cfg.model, cfg.config)
    if errors:
        print_environment_errors(errors)
        return 2
    engine = launch_engine(cfg)
    if engine is None:
        return 1
    try:
        response_text = engine.query({"id": "ping", "action": "query_version"})
        first_line = next((line for line in response_text.splitlines() if line.strip()), "")
        if not first_line:
            raise RuntimeError("KataGo returned an empty response")
        json.loads(first_line)
    except Exception as exc:  # noqa: BLE001
        print(f"Selftest failed: {exc}", file=sys.stderr)
        return 1
    finally:
        engine.terminate()
    print(first_line)
    return 0


def main() -> int:
    args = parse_args()
    cfg = EngineConfig(
        katago=resolve_path_argument(args.katago, "KATAGO", ".bin/katago"),
        model=resolve_path_argument(args.model, "MODEL", "models/latest.bin.gz"),
        config=resolve_path_argument(args.config, "KATAGO_CONFIG", "config/analysis.cfg"),
    )
    if args.selftest:
        return run_selftest(cfg)
    if not ensure_environment(cfg):
        return 1
    engine = launch_engine(cfg)
    if engine is None:
        return 1
    run_server(args, engine)
    return 0


if __name__ == "__main__":
    sys.exit(main())
