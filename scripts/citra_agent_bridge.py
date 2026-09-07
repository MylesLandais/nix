#!/usr/bin/env python3
"""Loopback control/observation bridge for an isolated Azahar session."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import signal
import socket
import subprocess
import tempfile
import threading
import time
from dataclasses import asdict, dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, cast
from urllib.parse import urlparse

ALLOWED_EXTENSIONS = {".3ds", ".cci", ".cxi", ".app"}
LOOPBACK_HOSTS = {"127.0.0.1", "::1", "localhost"}
BUTTON_KEYS = {
    "A": "a",
    "B": "s",
    "X": "z",
    "Y": "x",
    "L": "q",
    "R": "w",
    "ZL": "1",
    "ZR": "2",
    "START": "m",
    "SELECT": "n",
    "UP": "Up",
    "DOWN": "Down",
    "LEFT": "Left",
    "RIGHT": "Right",
    "DPAD_UP": "t",
    "DPAD_DOWN": "g",
    "DPAD_LEFT": "f",
    "DPAD_RIGHT": "h",
}


def allowed_cors_origin(origin: str | None) -> str | None:
    """Reflect only loopback browser origins; reject arbitrary web pages."""
    if not origin:
        return None
    parsed = urlparse(origin)
    if parsed.scheme in {"http", "https"} and parsed.hostname in LOOPBACK_HOSTS:
        return origin
    return None


class BridgeError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


@dataclass
class SessionState:
    state: str = "idle"
    revision: int = 0
    pid: int | None = None
    window_id: int | None = None
    rom_name: str | None = None
    gdb_port: int = 24689
    stream_status: str = "unavailable"
    stream_url: str | None = None
    snapshot_url: str | None = None
    error: str | None = None
    started_at: float | None = None
    mode: str = "azahar"


@dataclass
class BridgeConfig:
    host: str
    port: int
    state_dir: Path
    game_roots: tuple[Path, ...]
    azahar_bin: str
    ffmpeg_bin: str
    xdotool_bin: str
    display: str
    video_encoder: str
    test_source: bool = False
    touch_rect: tuple[int, int, int, int] | None = None


class GDBRemote:
    """Small read-only GDB remote client for Azahar's local stub."""

    def __init__(self, host: str, port: int, timeout: float = 3.0):
        self.host = host
        self.port = port
        self.timeout = timeout

    @staticmethod
    def _packet(payload: bytes) -> bytes:
        checksum = sum(payload) % 256
        return b"$" + payload + f"#{checksum:02x}".encode("ascii")

    @staticmethod
    def _read_packet(sock: socket.socket) -> bytes:
        while True:
            marker = sock.recv(1)
            if not marker:
                raise BridgeError(502, "gdb_eof", "Azahar's GDB stub closed the connection")
            if marker == b"$":
                break
        payload = bytearray()
        while True:
            char = sock.recv(1)
            if not char:
                raise BridgeError(502, "gdb_eof", "Azahar's GDB stub returned a partial packet")
            if char == b"#":
                break
            payload.extend(char)
        expected = sock.recv(2)
        actual = f"{sum(payload) % 256:02x}".encode("ascii")
        if expected.lower() != actual:
            sock.sendall(b"-")
            raise BridgeError(502, "gdb_checksum", "Azahar's GDB reply failed checksum validation")
        sock.sendall(b"+")
        return bytes(payload)

    def read_memory(self, address: int, length: int) -> bytes:
        if not 0 <= address <= 0xFFFFFFFF:
            raise BridgeError(422, "invalid_address", "address must fit in 32 bits")
        if not 1 <= length <= 4096:
            raise BridgeError(422, "invalid_length", "length must be between 1 and 4096 bytes")
        payload = f"m{address:x},{length:x}".encode("ascii")
        try:
            with socket.create_connection((self.host, self.port), timeout=self.timeout) as sock:
                sock.settimeout(self.timeout)
                sock.sendall(self._packet(payload))
                first = sock.recv(1)
                if first not in (b"+", b"$"):
                    raise BridgeError(502, "gdb_protocol", "Azahar's GDB stub did not acknowledge the request")
                if first == b"$":
                    # Put the marker back into a tiny receive adapter by reading this packet inline.
                    data = bytearray()
                    while True:
                        char = sock.recv(1)
                        if char == b"#":
                            break
                        if not char:
                            raise BridgeError(502, "gdb_eof", "Azahar's GDB stub returned a partial packet")
                        data.extend(char)
                    expected = sock.recv(2)
                    actual = f"{sum(data) % 256:02x}".encode("ascii")
                    if expected.lower() != actual:
                        raise BridgeError(502, "gdb_checksum", "Azahar's GDB reply failed checksum validation")
                    reply = bytes(data)
                else:
                    reply = self._read_packet(sock)
        except OSError as error:
            raise BridgeError(503, "gdb_unavailable", f"Azahar GDB stub is unavailable: {error}") from error
        if reply.startswith(b"E"):
            raise BridgeError(502, "gdb_error", f"Azahar GDB stub returned {reply.decode('ascii', 'replace')}")
        try:
            data = bytes.fromhex(reply.decode("ascii"))
        except ValueError as error:
            raise BridgeError(502, "gdb_protocol", "Azahar GDB reply was not hexadecimal") from error
        if len(data) != length:
            raise BridgeError(502, "gdb_short_read", f"expected {length} bytes, received {len(data)}")
        return data


class Bridge:
    def __init__(self, config: BridgeConfig):
        self.config = config
        self.config.state_dir.mkdir(parents=True, exist_ok=True)
        self.capture_dir = self.config.state_dir / "captures"
        self.stream_dir = self.config.state_dir / "stream"
        self.capture_dir.mkdir(parents=True, exist_ok=True)
        self.stream_dir.mkdir(parents=True, exist_ok=True)
        self.state = SessionState(
            gdb_port=int(os.environ.get("CITRA_AGENT_GDB_PORT", "24689")),
            stream_url=self._url("/stream/index.m3u8"),
            snapshot_url=self._url("/snapshot.jpg"),
            mode="test-source" if config.test_source else "azahar",
        )
        self.process: subprocess.Popen[bytes] | None = None
        self.stream_process: subprocess.Popen[bytes] | None = None
        self.lock = threading.RLock()
        if config.test_source:
            self._start_test_source()

    def _url(self, path: str) -> str:
        return f"http://{self.config.host}:{self.config.port}{path}"

    def _bump(self) -> None:
        self.state.revision += 1

    def public_state(self) -> dict[str, Any]:
        with self.lock:
            self._refresh_process_state()
            result = asdict(self.state)
            result["ok"] = self.state.state != "error"
            return result

    def health(self) -> dict[str, Any]:
        dependencies = {
            "azahar": shutil.which(self.config.azahar_bin) is not None,
            "ffmpeg": shutil.which(self.config.ffmpeg_bin) is not None,
            "xdotool": shutil.which(self.config.xdotool_bin) is not None,
        }
        required = ["ffmpeg"] if self.config.test_source else ["azahar", "ffmpeg", "xdotool"]
        return {
            "ok": all(dependencies[name] for name in required),
            "service": "citra-agent-bridge",
            "protocol_version": 1,
            "dependencies": dependencies,
            "state": self.public_state(),
        }

    def _validate_rom(self, raw_path: Any) -> Path:
        if not isinstance(raw_path, str) or not raw_path:
            raise BridgeError(422, "invalid_rom_path", "rom_path must be a non-empty string")
        candidate = Path(raw_path).expanduser().resolve(strict=True)
        if not candidate.is_file() or candidate.suffix.lower() not in ALLOWED_EXTENSIONS:
            raise BridgeError(422, "invalid_rom", "rom_path must be an existing 3DS image")
        if not any(candidate.is_relative_to(root) for root in self.config.game_roots):
            raise BridgeError(403, "rom_outside_root", "rom_path is outside the configured game roots")
        return candidate

    def start(self, payload: dict[str, Any]) -> dict[str, Any]:
        rom = self._validate_rom(payload.get("rom_path"))
        with self.lock:
            self.stop()
            self._clear_stream_dir()
            command = [
                self.config.azahar_bin,
                "-g",
                str(self.state.gdb_port),
                str(rom),
            ]
            env = os.environ.copy()
            env["QT_QPA_PLATFORM"] = "xcb"
            env["DISPLAY"] = self.config.display
            env.setdefault("XDG_DATA_HOME", str(self.config.state_dir / "xdg" / "data"))
            env.setdefault("XDG_CONFIG_HOME", str(self.config.state_dir / "xdg" / "config"))
            env.setdefault("XDG_CACHE_HOME", str(self.config.state_dir / "xdg" / "cache"))
            for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                Path(env[key]).mkdir(parents=True, exist_ok=True)
            try:
                self.process = subprocess.Popen(command, env=env, start_new_session=True)
            except OSError as error:
                raise BridgeError(503, "azahar_launch_failed", str(error)) from error
            self.state = SessionState(
                state="starting",
                revision=self.state.revision + 1,
                pid=self.process.pid,
                rom_name=rom.name,
                gdb_port=self.state.gdb_port,
                stream_status="starting",
                stream_url=self._url("/stream/index.m3u8"),
                snapshot_url=self._url("/snapshot.jpg"),
                started_at=time.time(),
            )
        window_id = self._find_window(self.process.pid, timeout=15.0)
        with self.lock:
            if window_id is None:
                self.state.state = "error"
                self.state.stream_status = "unavailable"
                self.state.error = "Azahar started but no visible XCB window appeared"
                self._bump()
                raise BridgeError(504, "window_timeout", self.state.error)
            self.state.window_id = window_id
            self.state.state = "running"
            self.state.error = None
            self._bump()
            self._start_window_stream(window_id)
            return self.public_state()

    def stop(self) -> dict[str, Any]:
        with self.lock:
            self._terminate(self.stream_process, timeout=3.0)
            self.stream_process = None
            self._terminate(self.process, timeout=5.0)
            self.process = None
            self.state.state = "idle"
            self.state.pid = None
            self.state.window_id = None
            self.state.rom_name = None
            self.state.stream_status = "unavailable"
            self.state.error = None
            self.state.started_at = None
            self._bump()
            return self.public_state()

    @staticmethod
    def _terminate(process: subprocess.Popen[bytes] | None, timeout: float) -> None:
        if process is None or process.poll() is not None:
            return
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(timeout=timeout)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                pass

    def _refresh_process_state(self) -> None:
        if self.process is not None and self.process.poll() is not None and self.state.state in {"starting", "running"}:
            self.state.state = "error"
            self.state.error = f"Azahar exited with status {self.process.returncode}"
            self.state.stream_status = "unavailable"
            self._bump()
        if self.stream_process is not None and self.stream_process.poll() is not None and self.state.stream_status == "ready":
            self.state.stream_status = "error"
            self._bump()

    def _find_window(self, pid: int, timeout: float) -> int | None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                result = subprocess.run(
                    [self.config.xdotool_bin, "search", "--onlyvisible", "--pid", str(pid)],
                    check=False,
                    capture_output=True,
                    text=True,
                    timeout=2.0,
                    env={**os.environ, "DISPLAY": self.config.display},
                )
                ids = [int(line) for line in result.stdout.splitlines() if line.strip().isdigit()]
                if ids:
                    return max(ids, key=self._window_area)
            except (OSError, subprocess.TimeoutExpired, ValueError):
                pass
            time.sleep(0.2)
        return None

    def _window_area(self, window_id: int) -> int:
        try:
            result = subprocess.run(
                [self.config.xdotool_bin, "getwindowgeometry", "--shell", str(window_id)],
                check=False,
                capture_output=True,
                text=True,
                timeout=2.0,
                env={**os.environ, "DISPLAY": self.config.display},
            )
            values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
            return int(values.get("WIDTH", "0")) * int(values.get("HEIGHT", "0"))
        except (OSError, subprocess.TimeoutExpired, ValueError):
            return 0

    def press(self, payload: dict[str, Any]) -> dict[str, Any]:
        buttons = payload.get("buttons")
        if isinstance(buttons, str):
            buttons = [buttons]
        if not isinstance(buttons, list) or not 1 <= len(buttons) <= 8:
            raise BridgeError(422, "invalid_buttons", "buttons must contain between 1 and 8 button names")
        normalized = [str(button).upper() for button in buttons]
        unknown = [button for button in normalized if button not in BUTTON_KEYS]
        if unknown:
            raise BridgeError(422, "unknown_button", f"unknown buttons: {', '.join(unknown)}")
        hold_ms = self._bounded_int(payload.get("hold_ms", 80), "hold_ms", 20, 2000)
        settle_ms = self._bounded_int(payload.get("settle_ms", 250), "settle_ms", 0, 5000)
        window_id = self._require_window()
        keys = [BUTTON_KEYS[button] for button in normalized]
        env = {**os.environ, "DISPLAY": self.config.display}
        try:
            for key in keys:
                subprocess.run(
                    [self.config.xdotool_bin, "keydown", "--window", str(window_id), "--clearmodifiers", key],
                    check=True,
                    timeout=3.0,
                    env=env,
                    capture_output=True,
                )
            time.sleep(hold_ms / 1000)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise BridgeError(502, "input_failed", str(error)) from error
        finally:
            for key in reversed(keys):
                subprocess.run(
                    [self.config.xdotool_bin, "keyup", "--window", str(window_id), key],
                    check=False,
                    timeout=3.0,
                    env=env,
                    capture_output=True,
                )
        time.sleep(settle_ms / 1000)
        return self.observe()

    def touch(self, payload: dict[str, Any]) -> dict[str, Any]:
        rect = self.config.touch_rect
        if rect is None:
            raise BridgeError(409, "touch_uncalibrated", "set CITRA_AGENT_TOUCH_RECT=x,y,width,height before using touch")
        x = self._bounded_float(payload.get("x"), "x", 0.0, 1.0)
        y = self._bounded_float(payload.get("y"), "y", 0.0, 1.0)
        hold_ms = self._bounded_int(payload.get("hold_ms", 80), "hold_ms", 20, 2000)
        settle_ms = self._bounded_int(payload.get("settle_ms", 250), "settle_ms", 0, 5000)
        window_id = self._require_window()
        left, top, width, height = rect
        px = left + round(x * max(width - 1, 0))
        py = top + round(y * max(height - 1, 0))
        env = {**os.environ, "DISPLAY": self.config.display}
        commands = [
            [self.config.xdotool_bin, "mousemove", "--window", str(window_id), str(px), str(py)],
            [self.config.xdotool_bin, "mousedown", "--window", str(window_id), "1"],
        ]
        try:
            for command in commands:
                subprocess.run(command, check=True, timeout=3.0, env=env, capture_output=True)
            time.sleep(hold_ms / 1000)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            raise BridgeError(502, "touch_failed", str(error)) from error
        finally:
            subprocess.run(
                [self.config.xdotool_bin, "mouseup", "--window", str(window_id), "1"],
                check=False,
                timeout=3.0,
                env=env,
                capture_output=True,
            )
        time.sleep(settle_ms / 1000)
        return self.observe()

    def observe(self) -> dict[str, Any]:
        target = self.capture_dir / "latest.jpg"
        temp_target = self.capture_dir / ".latest.jpg.tmp"
        if self.config.test_source and self.state.mode == "test-source":
            input_args = ["-f", "lavfi", "-i", "testsrc2=size=800x480:rate=1"]
        else:
            window_id = self._require_window()
            input_args = [
                "-f",
                "x11grab",
                "-draw_mouse",
                "0",
                "-window_id",
                str(window_id),
                "-i",
                self.config.display,
            ]
        command = [
            self.config.ffmpeg_bin,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            *input_args,
            "-frames:v",
            "1",
            "-q:v",
            "2",
            "-f",
            "image2",
            str(temp_target),
        ]
        try:
            subprocess.run(command, check=True, timeout=12.0, capture_output=True)
            temp_target.replace(target)
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            detail = error.stderr.decode("utf-8", "replace") if isinstance(error, subprocess.CalledProcessError) else str(error)
            raise BridgeError(502, "capture_failed", detail[-1000:]) from error
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        state = self.public_state()
        state.update(
            {
                "ok": True,
                "captured_at": time.time(),
                "snapshot_url": f"{self._url('/snapshot.jpg')}?revision={self.state.revision}",
                "snapshot_sha256": digest,
                "stream": {
                    "status": self.state.stream_status,
                    "url": self.state.stream_url,
                    "mime_type": "application/vnd.apple.mpegurl",
                },
            }
        )
        return state

    def read_memory(self, payload: dict[str, Any]) -> dict[str, Any]:
        self._require_window()
        address = self._parse_address(payload.get("address"))
        length = self._bounded_int(payload.get("length"), "length", 1, 4096)
        data = GDBRemote("127.0.0.1", self.state.gdb_port).read_memory(address, length)
        return {
            "ok": True,
            "address": f"0x{address:08x}",
            "length": len(data),
            "data_hex": data.hex(),
            "sha256": hashlib.sha256(data).hexdigest(),
            "revision": self.state.revision,
        }

    def _require_window(self) -> int:
        with self.lock:
            self._refresh_process_state()
            if self.state.state != "running" or self.state.window_id is None:
                raise BridgeError(409, "session_not_running", "an Azahar session is not running")
            return self.state.window_id

    def _clear_stream_dir(self) -> None:
        for path in self.stream_dir.iterdir():
            if path.is_file() and path.suffix in {".m3u8", ".ts", ".tmp"}:
                path.unlink()

    def _start_test_source(self) -> None:
        with self.lock:
            self._clear_stream_dir()
            command = self._stream_command(["-f", "lavfi", "-i", "testsrc2=size=800x480:rate=30"])
            self.stream_process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.state.state = "running"
            self.state.stream_status = "ready"
            self.state.started_at = time.time()
            self._bump()

    def _start_window_stream(self, window_id: int) -> None:
        self._clear_stream_dir()
        input_args = [
            "-f",
            "x11grab",
            "-draw_mouse",
            "0",
            "-framerate",
            "30",
            "-window_id",
            str(window_id),
            "-i",
            self.config.display,
        ]
        command = self._stream_command(input_args)
        self.stream_process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.state.stream_status = "ready"
        self._bump()

    def _stream_command(self, input_args: list[str]) -> list[str]:
        return [
            self.config.ffmpeg_bin,
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            *input_args,
            "-an",
            "-c:v",
            self.config.video_encoder,
            "-preset",
            "ultrafast",
            "-tune",
            "zerolatency",
            "-pix_fmt",
            "yuv420p",
            "-g",
            "30",
            "-sc_threshold",
            "0",
            "-f",
            "hls",
            "-hls_time",
            "1",
            "-hls_list_size",
            "4",
            "-hls_flags",
            "delete_segments+omit_endlist+independent_segments",
            str(self.stream_dir / "index.m3u8"),
        ]

    @staticmethod
    def _bounded_int(value: Any, name: str, minimum: int, maximum: int) -> int:
        try:
            parsed = int(value)
        except (TypeError, ValueError) as error:
            raise BridgeError(422, f"invalid_{name}", f"{name} must be an integer") from error
        if not minimum <= parsed <= maximum:
            raise BridgeError(422, f"invalid_{name}", f"{name} must be between {minimum} and {maximum}")
        return parsed

    @staticmethod
    def _bounded_float(value: Any, name: str, minimum: float, maximum: float) -> float:
        try:
            parsed = float(value)
        except (TypeError, ValueError) as error:
            raise BridgeError(422, f"invalid_{name}", f"{name} must be numeric") from error
        if not minimum <= parsed <= maximum:
            raise BridgeError(422, f"invalid_{name}", f"{name} must be between {minimum} and {maximum}")
        return parsed

    @staticmethod
    def _parse_address(value: Any) -> int:
        try:
            return int(value, 0) if isinstance(value, str) else int(value)
        except (TypeError, ValueError) as error:
            raise BridgeError(422, "invalid_address", "address must be an integer or 0x-prefixed string") from error


class BridgeHandler(BaseHTTPRequestHandler):
    @property
    def bridge(self) -> Bridge:
        return cast("BridgeServer", self.server).bridge

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._json(HTTPStatus.OK, self.bridge.health())
        elif path == "/v1/state":
            self._json(HTTPStatus.OK, self.bridge.public_state())
        elif path == "/snapshot.jpg":
            self._file(self.bridge.capture_dir / "latest.jpg", "image/jpeg")
        elif path.startswith("/stream/"):
            name = Path(path).name
            if name not in {path.name for path in self.bridge.stream_dir.iterdir() if path.is_file()}:
                self._error(BridgeError(404, "not_found", "stream artifact was not found"))
                return
            mime = "application/vnd.apple.mpegurl" if name.endswith(".m3u8") else "video/mp2t"
            self._file(self.bridge.stream_dir / name, mime)
        else:
            self._error(BridgeError(404, "not_found", "endpoint was not found"))

    def do_POST(self) -> None:
        try:
            payload = self._read_json()
            path = urlparse(self.path).path
            routes = {
                "/v1/session/start": lambda: self.bridge.start(payload),
                "/v1/session/stop": self.bridge.stop,
                "/v1/input": lambda: self.bridge.press(payload),
                "/v1/touch": lambda: self.bridge.touch(payload),
                "/v1/observe": self.bridge.observe,
                "/v1/memory/read": lambda: self.bridge.read_memory(payload),
            }
            handler = routes.get(path)
            if handler is None:
                raise BridgeError(404, "not_found", "endpoint was not found")
            self._json(HTTPStatus.OK, handler())
        except BridgeError as error:
            self._error(error)
        except Exception as error:  # pragma: no cover - final HTTP containment boundary
            self._error(BridgeError(500, "internal_error", str(error)))

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._common_headers()
        self.send_header("access-control-allow-headers", "content-type")
        self.send_header("access-control-allow-methods", "GET, POST, OPTIONS")
        self.send_header("content-length", "0")
        self.end_headers()

    def _read_json(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("content-length", "0"))
        except ValueError as error:
            raise BridgeError(400, "invalid_content_length", "invalid Content-Length") from error
        if length > 1_048_576:
            raise BridgeError(413, "request_too_large", "request body exceeds 1 MiB")
        if length == 0:
            return {}
        try:
            payload = json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise BridgeError(400, "invalid_json", "request body must be valid JSON") from error
        if not isinstance(payload, dict):
            raise BridgeError(400, "invalid_json", "request JSON must be an object")
        return payload

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self._common_headers()
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path: Path, mime: str) -> None:
        if not path.is_file():
            self._error(BridgeError(404, "not_found", "artifact was not found"))
            return
        body = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("content-type", mime)
        self.send_header("content-length", str(len(body)))
        self._common_headers()
        self.end_headers()
        self.wfile.write(body)

    def _common_headers(self) -> None:
        self.send_header("cache-control", "no-store")
        if origin := allowed_cors_origin(self.headers.get("origin")):
            self.send_header("access-control-allow-origin", origin)
            self.send_header("vary", "origin")
        self.send_header("x-content-type-options", "nosniff")

    def _error(self, error: BridgeError) -> None:
        self._json(error.status, {"ok": False, "error": {"code": error.code, "message": error.message}})

    def log_message(self, format: str, *args: Any) -> None:
        print(f"citra-agent-bridge: {format % args}")


class BridgeServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], bridge: Bridge):
        self.bridge = bridge
        super().__init__(address, BridgeHandler)

    def server_close(self) -> None:
        self.bridge.stop()
        super().server_close()


def parse_touch_rect(raw: str | None) -> tuple[int, int, int, int] | None:
    if not raw:
        return None
    try:
        values = tuple(int(part.strip()) for part in raw.split(","))
    except ValueError as error:
        raise SystemExit("CITRA_AGENT_TOUCH_RECT must be x,y,width,height") from error
    if len(values) != 4 or values[2] <= 0 or values[3] <= 0:
        raise SystemExit("CITRA_AGENT_TOUCH_RECT must be x,y,width,height with positive dimensions")
    return values


def build_config(args: argparse.Namespace) -> BridgeConfig:
    roots = tuple(Path(root).expanduser().resolve() for root in args.game_root)
    return BridgeConfig(
        host=args.host,
        port=args.port,
        state_dir=Path(args.state_dir).expanduser().resolve(),
        game_roots=roots,
        azahar_bin=os.environ.get("CITRA_AGENT_AZAHAR_BIN", "azahar-maya"),
        ffmpeg_bin=os.environ.get("CITRA_AGENT_FFMPEG_BIN", "ffmpeg"),
        xdotool_bin=os.environ.get("CITRA_AGENT_XDOTOOL_BIN", "xdotool"),
        display=os.environ.get("DISPLAY", ":0"),
        video_encoder=os.environ.get("CITRA_AGENT_VIDEO_ENCODER", "libx264"),
        test_source=args.test_source,
        touch_rect=parse_touch_rect(os.environ.get("CITRA_AGENT_TOUCH_RECT")),
    )


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--host", default=os.environ.get("CITRA_AGENT_HOST", "127.0.0.1"))
    result.add_argument("--port", type=int, default=int(os.environ.get("CITRA_AGENT_PORT", "47833")))
    result.add_argument(
        "--state-dir",
        default=os.environ.get("CITRA_AGENT_STATE_DIR", "~/.local/state/citra-agent"),
    )
    result.add_argument(
        "--game-root",
        action="append",
        default=[os.environ.get("CITRA_AGENT_GAME_ROOT", "~/Games/3DS")],
    )
    result.add_argument("--test-source", action="store_true", help="serve generated video without Azahar")
    return result


def main() -> int:
    args = parser().parse_args()
    config = build_config(args)
    if config.host not in LOOPBACK_HOSTS:
        raise SystemExit("citra-agent-bridge only permits loopback bind addresses")
    bridge = Bridge(config)
    server = BridgeServer((config.host, config.port), bridge)
    print(f"citra-agent-bridge listening on http://{config.host}:{config.port}")
    try:
        server.serve_forever(poll_interval=0.2)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
