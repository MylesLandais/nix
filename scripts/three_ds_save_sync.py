#!/usr/bin/env python3
"""Non-destructive Checkpoint save snapshot and sync utility."""

from __future__ import annotations

import argparse
import ftplib
import hashlib
import json
import os
import re
import selectors
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable, TextIO, cast

MANIFEST_NAME = "manifest.json"
BUFFER_SIZE = 1024 * 1024


class SyncError(Exception):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(BUFFER_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


def iter_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        if path.is_symlink():
            raise SyncError(f"symbolic links are not accepted in save snapshots: {path}")
        if path.is_file() and path.name != MANIFEST_NAME:
            yield path


def build_manifest(root: Path, source: str) -> dict[str, Any]:
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise SyncError(f"save source is not a directory: {root}")
    files = []
    for path in iter_files(root):
        relative = path.relative_to(root).as_posix()
        files.append(
            {
                "path": relative,
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    canonical = json.dumps(files, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {
        "schema_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "source": source,
        "file_count": len(files),
        "byte_count": sum(item["size"] for item in files),
        "root_digest": hashlib.sha256(canonical).hexdigest(),
        "files": files,
    }


def validate_name(name: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", name):
        raise SyncError("snapshot name must use only letters, numbers, dot, underscore, and dash")
    return name


def copy_tree(source: Path, destination: Path, *, include_manifest: bool = False) -> None:
    source = source.resolve(strict=True)
    destination.mkdir(parents=True, exist_ok=False)
    for path in sorted(source.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(source)
        if path.name == MANIFEST_NAME and not include_manifest:
            continue
        target = destination / relative
        if path.is_symlink():
            raise SyncError(f"symbolic links are not accepted: {path}")
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif path.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)


def create_snapshot(source: Path, destination_root: Path, name: str, source_label: str) -> dict[str, Any]:
    source = source.expanduser().resolve(strict=True)
    destination_root = destination_root.expanduser().resolve()
    destination_root.mkdir(parents=True, exist_ok=True)
    target = destination_root / validate_name(name)
    if target.exists():
        raise SyncError(f"snapshot already exists: {target}")
    staging = Path(tempfile.mkdtemp(prefix=f".{name}.", dir=destination_root))
    try:
        for path in sorted(source.rglob("*"), key=lambda item: item.as_posix()):
            relative = path.relative_to(source)
            destination = staging / relative
            if path.is_symlink():
                raise SyncError(f"symbolic links are not accepted: {path}")
            if path.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            elif path.is_file():
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, destination)
        manifest = build_manifest(staging, source_label)
        (staging / MANIFEST_NAME).write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        staging.replace(target)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return {"ok": True, "snapshot": str(target), "manifest": manifest}


def verify_snapshot(snapshot: Path) -> dict[str, Any]:
    snapshot = snapshot.expanduser().resolve(strict=True)
    manifest_path = snapshot / MANIFEST_NAME
    if not manifest_path.is_file():
        raise SyncError(f"snapshot manifest is missing: {manifest_path}")
    expected = json.loads(manifest_path.read_text(encoding="utf-8"))
    actual = build_manifest(snapshot, expected.get("source", "verification"))
    if expected.get("root_digest") != actual["root_digest"]:
        raise SyncError(
            f"snapshot digest mismatch: manifest={expected.get('root_digest')} actual={actual['root_digest']}"
        )
    if expected.get("file_count") != actual["file_count"]:
        raise SyncError("snapshot file count does not match its manifest")
    return expected


def push_local(snapshot: Path, destination: Path, confirm_digest: str) -> dict[str, Any]:
    snapshot = snapshot.expanduser().resolve(strict=True)
    destination = destination.expanduser().resolve()
    manifest = verify_snapshot(snapshot)
    if confirm_digest != manifest["root_digest"]:
        raise SyncError("--confirm-digest must exactly match the verified source snapshot root_digest")
    destination.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    backup = destination.parent / f"{destination.name}.pre-push-{timestamp}"
    if backup.exists():
        raise SyncError(f"refusing to overwrite existing backup: {backup}")
    staging = Path(tempfile.mkdtemp(prefix=f".{destination.name}.incoming.", dir=destination.parent))
    shutil.rmtree(staging)
    try:
        copy_tree(snapshot, staging)
        pushed_manifest = build_manifest(staging, f"push:{snapshot}")
        if pushed_manifest["root_digest"] != manifest["root_digest"]:
            raise SyncError("staged push differs from the verified source snapshot")
        if destination.exists():
            destination.replace(backup)
        staging.replace(destination)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        if backup.exists() and not destination.exists():
            backup.replace(destination)
        raise
    return {
        "ok": True,
        "destination": str(destination),
        "backup": str(backup) if backup.exists() else None,
        "root_digest": manifest["root_digest"],
    }


def ftp_download_tree(
    host: str,
    port: int,
    remote_path: str,
    destination: Path,
    username: str,
    password: str,
) -> None:
    if not re.fullmatch(r"[A-Za-z0-9._:-]+", host):
        raise SyncError("FTP host contains unsupported characters")
    if "\n" in remote_path or "\r" in remote_path or not remote_path.startswith("/"):
        raise SyncError("FTP remote path must be an absolute path without newlines")
    destination.mkdir(parents=True, exist_ok=False)
    try:
        with ftplib.FTP() as ftp:
            ftp.connect(host, port, timeout=10)
            ftp.login(username, password)
            ftp.cwd(remote_path)
            _ftp_walk(ftp, destination)
    except ftplib.all_errors as error:
        raise SyncError(f"FTP pull failed: {error}") from error


def _ftp_walk(ftp: ftplib.FTP, destination: Path) -> None:
    try:
        entries = list(ftp.mlsd())
    except ftplib.all_errors as error:
        raise SyncError("the 3DS FTP server must support MLSD for safe recursive pulls") from error
    for name, facts in entries:
        if name in {".", ".."} or "/" in name or "\\" in name:
            continue
        target = destination / name
        entry_type = facts.get("type", "")
        if entry_type == "dir":
            target.mkdir()
            ftp.cwd(name)
            _ftp_walk(ftp, target)
            ftp.cwd("..")
        elif entry_type == "file":
            with target.open("wb") as handle:
                ftp.retrbinary(f"RETR {name}", handle.write, blocksize=BUFFER_SIZE)


def pull_ftp(args: argparse.Namespace) -> dict[str, Any]:
    destination_root = Path(args.destination_root).expanduser().resolve()
    destination_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="3ds-save-ftp-", dir=destination_root) as temporary:
        temporary_path = Path(temporary) / "download"
        ftp_download_tree(
            args.host,
            args.port,
            args.remote_path,
            temporary_path,
            args.username,
            args.password,
        )
        return create_snapshot(
            temporary_path,
            destination_root,
            args.name,
            f"ftp://{args.host}:{args.port}{args.remote_path}",
        )


def receive_checkpoint_wireless(
    chlink_bin: Path,
    destination_root: Path,
    name: str,
    *,
    port: int = 8000,
    timeout_seconds: int = 300,
) -> dict[str, Any]:
    if not 1 <= port <= 65535:
        raise SyncError("wireless receive port must be between 1 and 65535")
    if timeout_seconds < 1:
        raise SyncError("wireless receive timeout must be positive")
    chlink_bin = chlink_bin.expanduser().resolve(strict=True)
    if not chlink_bin.is_file() or not os.access(chlink_bin, os.X_OK):
        raise SyncError(f"Checkpoint chlink executable is not runnable: {chlink_bin}")

    destination_root = destination_root.expanduser().resolve()
    destination_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="3ds-save-chlink-", dir=destination_root) as temporary:
        receive_root = Path(temporary) / "received"
        command = [
            str(chlink_bin),
            "receive",
            "--out",
            str(receive_root),
            "--once",
            "--json",
            "--port",
            str(port),
        ]
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if process.stdout is None or process.stderr is None:
            process.kill()
            raise SyncError("failed to capture Checkpoint chlink output")

        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ, "stdout")
        selector.register(process.stderr, selectors.EVENT_READ, "stderr")
        deadline = time.monotonic() + timeout_seconds
        received_event: dict[str, Any] | None = None
        listening_seen = False
        errors: list[str] = []
        try:
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                    raise SyncError(f"Checkpoint wireless receive timed out after {timeout_seconds} seconds")

                ready = selector.select(timeout=min(remaining, 0.5))
                if not ready and process.poll() is not None:
                    break
                for key, _ in ready:
                    stream = cast(TextIO, key.fileobj)
                    line = stream.readline()
                    if line == "":
                        selector.unregister(key.fileobj)
                        continue
                    line = line.strip()
                    if not line:
                        continue
                    if key.data == "stderr":
                        errors.append(line)
                        continue
                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError as error:
                        raise SyncError(f"Checkpoint chlink emitted invalid JSON: {line}") from error
                    if event.get("event") == "listening":
                        listening_seen = True
                        status = {
                            "event": "checkpoint_receive_listening",
                            "ips": event.get("ips", []),
                            "port": event.get("port", port),
                            "pin": event.get("pin"),
                        }
                        print(json.dumps(status, sort_keys=True), file=sys.stderr, flush=True)
                    elif event.get("event") == "received":
                        received_event = event

            return_code = process.wait(timeout=5)
        finally:
            selector.close()
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
            process.stderr.close()

        if return_code != 0:
            detail = errors[-1] if errors else f"exit status {return_code}"
            raise SyncError(f"Checkpoint chlink receive failed: {detail}")
        if not listening_seen or received_event is None:
            raise SyncError("Checkpoint chlink exited without receiving a backup")

        saved_path_value = received_event.get("savedPath")
        if not isinstance(saved_path_value, str) or not saved_path_value:
            raise SyncError("Checkpoint chlink did not report a saved backup path")
        receive_root = receive_root.resolve(strict=True)
        saved_path = Path(saved_path_value).resolve(strict=True)
        try:
            saved_path.relative_to(receive_root)
        except ValueError as error:
            raise SyncError("Checkpoint chlink reported a path outside the receive staging root") from error
        source_label = "checkpoint-wireless:{data_type}:{backup_name}".format(
            data_type=received_event.get("dataType", "unknown"),
            backup_name=received_event.get("backupName", "unknown"),
        )
        return create_snapshot(saved_path, destination_root, name, source_label)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    pull = subparsers.add_parser("pull-local", help="snapshot a mounted Checkpoint save")
    pull.add_argument("--source", required=True)
    pull.add_argument("--destination-root", required=True)
    pull.add_argument("--name", required=True)

    ftp = subparsers.add_parser("pull-ftp", help="pull a Checkpoint save from ftpd")
    ftp.add_argument("--host", required=True)
    ftp.add_argument("--port", type=int, default=5000)
    ftp.add_argument("--remote-path", required=True)
    ftp.add_argument("--destination-root", required=True)
    ftp.add_argument("--name", required=True)
    ftp.add_argument("--username", default="anonymous")
    ftp.add_argument("--password", default="anonymous@")

    wireless = subparsers.add_parser(
        "receive-wireless",
        help="receive one backup from Checkpoint's wireless Send action and snapshot it",
    )
    wireless.add_argument("--destination-root", required=True)
    wireless.add_argument("--name", required=True)
    wireless.add_argument("--port", type=int, default=int(os.environ.get("CHECKPOINT_CHLINK_PORT", "8000")))
    wireless.add_argument("--timeout-seconds", type=int, default=300)
    wireless.add_argument(
        "--chlink-bin",
        default=os.environ.get("CHECKPOINT_CHLINK_BIN", shutil.which("chlink") or "chlink"),
    )

    verify = subparsers.add_parser("verify", help="verify a snapshot against its manifest")
    verify.add_argument("snapshot")

    push = subparsers.add_parser("push-local", help="replace a mounted save after a verified backup")
    push.add_argument("--snapshot", required=True)
    push.add_argument("--destination", required=True)
    push.add_argument("--confirm-digest", required=True)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "pull-local":
            result = create_snapshot(
                Path(args.source),
                Path(args.destination_root),
                args.name,
                f"local:{Path(args.source).expanduser().resolve()}",
            )
        elif args.command == "pull-ftp":
            result = pull_ftp(args)
        elif args.command == "receive-wireless":
            result = receive_checkpoint_wireless(
                Path(args.chlink_bin),
                Path(args.destination_root),
                args.name,
                port=args.port,
                timeout_seconds=args.timeout_seconds,
            )
        elif args.command == "verify":
            manifest = verify_snapshot(Path(args.snapshot))
            result = {"ok": True, "snapshot": str(Path(args.snapshot).expanduser().resolve()), "manifest": manifest}
        elif args.command == "push-local":
            result = push_local(Path(args.snapshot), Path(args.destination), args.confirm_digest)
        else:  # pragma: no cover
            raise SyncError(f"unsupported command: {args.command}")
    except (SyncError, FileNotFoundError, PermissionError, json.JSONDecodeError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, sort_keys=True), file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
