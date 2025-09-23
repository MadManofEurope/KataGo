#!/usr/bin/env python3
"""Expose KataGo's JSON analysis engine over TCP/HTTP."""

import argparse
import json
import logging
import socketserver
import subprocess
import sys
import threading
from typing import List

LOG = logging.getLogger("katago-proxy")


def build_command(args: argparse.Namespace) -> List[str]:
    cmd: List[str] = [
        args.katago,
        "analysis",
        "-model",
        args.model,
        "-config",
        args.config,
    ]
    for override in args.override_config:
        cmd.extend(["-override-config", override])
    return cmd


class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

    def __init__(self, server_address, handler_class, base_cmd: List[str]):
        super().__init__(server_address, handler_class)
        self.base_cmd = list(base_cmd)


class KataGoRequestHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:  # type: ignore[override]
        try:
            # Peek without consuming to decide if this is HTTP or raw JSON.
            initial = self.rfile.peek(4)
        except AttributeError:
            initial = self.rfile.read(0)
        if initial and initial.startswith((b"POST", b"GET")):
            self._handle_http()
        else:
            self._handle_stream()

    def _spawn_katago(self) -> subprocess.Popen:
        cmd = list(self.server.base_cmd)
        LOG.debug("Launching KataGo: %s", " ".join(cmd))
        return subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr,
            text=True,
            bufsize=1,
        )

    def _handle_stream(self) -> None:
        proc = self._spawn_katago()

        def forward_stdout() -> None:
            assert proc.stdout is not None
            while True:
                line = proc.stdout.readline()
                if not line:
                    break
                try:
                    self.wfile.write(line.encode("utf-8"))
                    self.wfile.flush()
                except BrokenPipeError:
                    break

        thread = threading.Thread(target=forward_stdout, daemon=True)
        thread.start()

        try:
            assert proc.stdin is not None
            while True:
                data = self.rfile.readline()
                if not data:
                    break
                proc.stdin.write(data.decode("utf-8", "ignore"))
                proc.stdin.flush()
        finally:
            try:
                proc.stdin.close()  # type: ignore[call-arg]
            except Exception:
                pass
            proc.wait(timeout=5)

    def _handle_http(self) -> None:
        request_line = self.rfile.readline().decode("latin1", "ignore")
        parts = request_line.strip().split()
        if len(parts) != 3:
            self._send_http_error(400, "Bad Request")
            return
        method, _path, _version = parts
        if method.upper() != "POST":
            self._send_http_error(405, "Method Not Allowed")
            return

        headers = {}
        while True:
            line = self.rfile.readline()
            if line in (b"\r\n", b"\n", b""):
                break
            key, _, value = line.decode("latin1", "ignore").partition(":")
            headers[key.strip().lower()] = value.strip()

        try:
            length = int(headers.get("content-length", "0"))
        except ValueError:
            self._send_http_error(411, "Length Required")
            return

        body = self.rfile.read(length) if length else b""
        if not body:
            self._send_http_error(400, "Empty body")
            return

        try:
            json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_http_error(400, "Body must be valid JSON")
            return

        proc = self._spawn_katago()
        assert proc.stdin is not None and proc.stdout is not None

        try:
            text_body = body.decode("utf-8")
            if not text_body.endswith("\n"):
                text_body += "\n"
            proc.stdin.write(text_body)
            proc.stdin.flush()
            try:
                proc.stdin.close()  # type: ignore[call-arg]
            except Exception:
                pass

            responses: List[str] = []
            while True:
                line = proc.stdout.readline()
                if not line:
                    break
                responses.append(line)
        finally:
            proc.wait(timeout=5)

        if not responses:
            self._send_http_error(502, "No response from KataGo")
            return

        response_text = "".join(responses)
        payload = response_text.encode("utf-8")
        headers_out = (
            f"HTTP/1.1 200 OK\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(payload)}\r\n"
            f"Connection: close\r\n\r\n"
        ).encode("ascii")
        self.wfile.write(headers_out)
        self.wfile.write(payload)
        self.wfile.flush()

    def _send_http_error(self, status: int, message: str) -> None:
        body = json.dumps({"error": message, "status": status})
        payload = body.encode("utf-8")
        headers_out = (
            f"HTTP/1.1 {status} {message}\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(payload)}\r\n"
            f"Connection: close\r\n\r\n"
        ).encode("ascii")
        try:
            self.wfile.write(headers_out)
            self.wfile.write(payload)
            self.wfile.flush()
        except BrokenPipeError:
            pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=2388)
    parser.add_argument("--katago", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument(
        "--override-config",
        action="append",
        default=[],
        help="Additional -override-config entries passed to KataGo",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"],
    )
    args = parser.parse_args()

    logging.basicConfig(level=getattr(logging, args.log_level))
    base_cmd = build_command(args)

    server = ThreadedTCPServer((args.listen, args.port), KataGoRequestHandler, base_cmd)
    LOG.info("Serving KataGo on %s:%s", args.listen, args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        LOG.info("Shutting down KataGo proxy")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
