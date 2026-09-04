#!/usr/bin/env python3
"""Extract and inventory an owned Fire Emblem Echoes 3DS dump."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable

BUFFER_SIZE = 1024 * 1024
CATEGORIES = {
    ".bch": "cgfx-model-or-texture",
    ".bcres": "cgfx-resource",
    ".bcstm": "ctr-audio-stream",
    ".bcsar": "ctr-sound-archive",
    ".cmb": "model-container",
    ".msbt": "message-binary-text",
    ".lz": "compressed",
    ".arc": "archive",
    ".bin": "binary",
}
MAGIC_NAMES = {
    b"SARC": "sarc",
    b"Yaz0": "yaz0",
    b"MsgStdBn": "msbt",
    b"CGFX": "cgfx",
    b"CSTM": "bcstm",
}


class DatamineError(Exception):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(BUFFER_SIZE):
            digest.update(chunk)
    return digest.hexdigest()


def file_magic(path: Path) -> str | None:
    with path.open("rb") as handle:
        prefix = handle.read(16)
    for magic, name in MAGIC_NAMES.items():
        if prefix.startswith(magic):
            return name
    return None


def iter_files(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix()):
        if path.is_symlink():
            raise DatamineError(f"symbolic links are not accepted in datamine trees: {path}")
        if path.is_file():
            yield path


def build_index(root: Path, source: str | None = None) -> dict[str, Any]:
    root = root.expanduser().resolve(strict=True)
    if not root.is_dir():
        raise DatamineError(f"index root is not a directory: {root}")
    entries = []
    category_counts: dict[str, int] = {}
    for path in iter_files(root):
        suffix = path.suffix.lower()
        category = CATEGORIES.get(suffix, "other")
        category_counts[category] = category_counts.get(category, 0) + 1
        entries.append(
            {
                "path": path.relative_to(root).as_posix(),
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
                "extension": suffix,
                "category": category,
                "magic": file_magic(path),
            }
        )
    canonical = json.dumps(entries, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {
        "schema_version": 1,
        "game": "Fire Emblem Echoes: Shadows of Valentia",
        "created_at": datetime.now(UTC).isoformat(),
        "source": source,
        "root": str(root),
        "file_count": len(entries),
        "byte_count": sum(entry["size"] for entry in entries),
        "tree_digest": hashlib.sha256(canonical).hexdigest(),
        "category_counts": dict(sorted(category_counts.items())),
        "files": entries,
    }


def ensure_outside_git(path: Path) -> None:
    current = path.expanduser().resolve()
    for parent in (current, *current.parents):
        if (parent / ".git").exists():
            raise DatamineError(
                f"refusing to extract copyrighted data inside Git worktree {parent}; choose a state/data directory"
            )


def run_ctrtool(ctrtool: str, args: list[str], *, allow_failure: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [ctrtool, "--verify", *args],
        check=False,
        capture_output=True,
        text=True,
        timeout=10 * 60,
    )
    if result.returncode != 0 and not allow_failure:
        detail = (result.stderr or result.stdout).strip()
        raise DatamineError(f"ctrtool failed ({result.returncode}): {detail[-2000:]}")
    return result


def extract_owned_dump(image: Path, output: Path, ctrtool: str, seeddb: Path | None) -> dict[str, Any]:
    image = image.expanduser().resolve(strict=True)
    output = output.expanduser().resolve()
    ensure_outside_git(output)
    if output.exists() and any(output.iterdir()):
        raise DatamineError(f"output directory must not already contain files: {output}")
    output.mkdir(parents=True, exist_ok=True)
    ctrtool_path = shutil.which(ctrtool)
    if ctrtool_path is None:
        raise DatamineError(f"ctrtool executable was not found: {ctrtool}")
    common = [f"--seeddb={seeddb.expanduser().resolve(strict=True)}"] if seeddb else []
    source_sha256 = sha256_file(image)
    contents = output / "contents"
    contents.mkdir()

    if image.suffix.lower() in {".3ds", ".cci", ".cia"}:
        run_ctrtool(ctrtool_path, [*common, f"--contents={contents}", str(image)])
        candidates = list(iter_files(contents))
    else:
        candidates = [image]

    extracted_partitions = []
    for index, candidate in enumerate(candidates):
        partition = output / f"partition-{index:02d}"
        partition.mkdir()
        exefs = partition / "exefs.bin"
        romfs = partition / "romfs.bin"
        result = run_ctrtool(
            ctrtool_path,
            [*common, f"--exefs={exefs}", f"--romfs={romfs}", str(candidate)],
            allow_failure=True,
        )
        if result.returncode != 0:
            partition.rmdir()
            continue
        partition_result: dict[str, Any] = {
            "index": index,
            "source": candidate.relative_to(output).as_posix() if candidate.is_relative_to(output) else candidate.name,
            "exefs": False,
            "romfs": False,
        }
        if exefs.is_file() and exefs.stat().st_size > 0:
            exefs_dir = partition / "exefs"
            exefs_dir.mkdir()
            run_ctrtool(ctrtool_path, [*common, f"--exefsdir={exefs_dir}", str(exefs)])
            partition_result["exefs"] = True
        if romfs.is_file() and romfs.stat().st_size > 0:
            romfs_dir = partition / "romfs"
            romfs_dir.mkdir()
            run_ctrtool(ctrtool_path, [*common, f"--romfsdir={romfs_dir}", str(romfs)])
            partition_result["romfs"] = True
        extracted_partitions.append(partition_result)

    if not extracted_partitions:
        raise DatamineError(
            "no NCCH partition could be extracted; use a decrypted owned dump and provide --seeddb when required"
        )
    manifest = build_index(output, source=f"sha256:{source_sha256}")
    manifest["source_image_name"] = image.name
    manifest["source_image_sha256"] = source_sha256
    manifest["partitions"] = extracted_partitions
    manifest_path = output / "fe-echoes-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {
        "ok": True,
        "output": str(output),
        "manifest": str(manifest_path),
        "source_image_sha256": source_sha256,
        "partitions": extracted_partitions,
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    index = subparsers.add_parser("index", help="hash and classify an extracted tree")
    index.add_argument("root")
    index.add_argument("--output")
    index.add_argument("--source")

    extract = subparsers.add_parser("extract", help="extract an owned decrypted 3DS image")
    extract.add_argument("image")
    extract.add_argument("output")
    extract.add_argument("--ctrtool", default=os.environ.get("CTRTOOL_BIN", "ctrtool"))
    extract.add_argument("--seeddb")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "index":
            manifest = build_index(Path(args.root), args.source)
            if args.output:
                output = Path(args.output).expanduser().resolve()
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
                result: dict[str, Any] = {"ok": True, "manifest": str(output), **manifest}
            else:
                result = {"ok": True, **manifest}
        elif args.command == "extract":
            result = extract_owned_dump(
                Path(args.image),
                Path(args.output),
                args.ctrtool,
                Path(args.seeddb) if args.seeddb else None,
            )
        else:  # pragma: no cover
            raise DatamineError(f"unsupported command: {args.command}")
    except (DatamineError, FileNotFoundError, PermissionError, json.JSONDecodeError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, sort_keys=True), file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
