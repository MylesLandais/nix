#!/usr/bin/env python3
"""Keep a Chromium-family Helium profile registered and consistently configured."""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import socket
import stat
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterator


DEFAULT_PROFILE = "Default"
DEFAULT_NAME = "Your Helium"
DEFAULT_AVATAR_INDEX = 26


def _json_object(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Helium profile guard: cannot read {path}: {exc}", file=sys.stderr)
        return None
    if not isinstance(value, dict):
        print(f"Helium profile guard: {path} does not contain a JSON object", file=sys.stderr)
        return None
    return value


def _atomic_json_write(path: Path, value: dict[str, Any]) -> None:
    if path.is_symlink():
        raise RuntimeError(f"refusing to replace symlink {path}")

    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.helium-guard-",
        dir=path.parent,
        text=True,
    )
    temporary = Path(temporary_name)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            temporary.unlink()
        raise


def _runtime_lock_filename(data_dir: Path) -> str:
    digest = hashlib.sha256(str(data_dir.resolve()).encode("utf-8")).hexdigest()[:20]
    return f"helium-profile-guard-{os.getuid()}-{digest}.lock"


@contextlib.contextmanager
def _guard_lock(data_dir: Path) -> Iterator[None]:
    filename = _runtime_lock_filename(data_dir)
    runtime_dirs = [Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")), Path("/tmp")]
    last_error: OSError | None = None

    for runtime_dir in runtime_dirs:
        handle = None
        try:
            runtime_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            lock_path = runtime_dir / filename
            handle = lock_path.open("a+", encoding="utf-8")
            os.chmod(lock_path, 0o600)
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        except OSError as error:
            if handle is not None:
                handle.close()
            last_error = error
            continue

        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
            handle.close()
        return

    if last_error is not None:
        raise last_error
    raise OSError("unable to create Helium profile guard lock")


def _browser_lock_is_live(data_dir: Path) -> bool:
    """Return true unless SingletonLock proves that no browser owns the data dir."""

    lock = data_dir / "SingletonLock"
    try:
        target = os.readlink(lock)
    except FileNotFoundError:
        return False
    except OSError:
        return True

    host, separator, pid_text = target.rpartition("-")
    if not separator or host != socket.gethostname() or not pid_text.isdigit():
        return True

    try:
        os.kill(int(pid_text), 0)
    except ProcessLookupError:
        try:
            if os.readlink(lock) == target:
                os.unlink(lock)
        except FileNotFoundError:
            pass
        except OSError:
            return True
        return False
    except PermissionError:
        return True
    return True


def _ensure_once(values: Any, profile_dir: str) -> list[Any]:
    existing = values if isinstance(values, list) else []
    return [value for value in existing if value != profile_dir] + [profile_dir]


def _profile_values(preferences: dict[str, Any] | None) -> tuple[str, int, bool]:
    profile = preferences.get("profile") if isinstance(preferences, dict) else None
    profile = profile if isinstance(profile, dict) else {}

    name = profile.get("name")
    has_preference_name = isinstance(name, str) and bool(name.strip())
    if not has_preference_name:
        name = DEFAULT_NAME

    avatar_index = profile.get("avatar_index")
    if not isinstance(avatar_index, int) or isinstance(avatar_index, bool):
        avatar_index = DEFAULT_AVATAR_INDEX

    return name, avatar_index, has_preference_name


def _repair_preferences(preferences: dict[str, Any]) -> bool:
    changed = False

    helium = preferences.setdefault("helium", {})
    if not isinstance(helium, dict):
        helium = {}
        preferences["helium"] = helium
        changed = True
    services = helium.setdefault("services", {})
    if not isinstance(services, dict):
        services = {}
        helium["services"] = services
        changed = True
    for key, value in {"enabled": True, "ext_proxy": True, "consented": True}.items():
        if services.get(key) != value:
            services[key] = value
            changed = True

    vertical_tabs = preferences.setdefault("vertical_tabs", {})
    if not isinstance(vertical_tabs, dict):
        vertical_tabs = {}
        preferences["vertical_tabs"] = vertical_tabs
        changed = True
    for key, value in {
        "enabled": True,
        "collapsed_state": False,
        "uncollapsed_width": 200,
    }.items():
        if vertical_tabs.get(key) != value:
            vertical_tabs[key] = value
            changed = True

    return changed


def _repair_local_state(
    local_state: dict[str, Any],
    profile_dir: str,
    preferences: dict[str, Any] | None,
) -> bool:
    changed = False
    profile_root = local_state.setdefault("profile", {})
    if not isinstance(profile_root, dict):
        profile_root = {}
        local_state["profile"] = profile_root
        changed = True

    info_cache = profile_root.setdefault("info_cache", {})
    if not isinstance(info_cache, dict):
        info_cache = {}
        profile_root["info_cache"] = info_cache
        changed = True

    existing = info_cache.get(profile_dir)
    entry = dict(existing) if isinstance(existing, dict) else {}
    name, avatar_index, has_preference_name = _profile_values(preferences)
    desired = {
        "name": name,
        "avatar_index": avatar_index,
        "avatar_icon": f"chrome://theme/IDR_PROFILE_AVATAR_{avatar_index}",
        "is_using_default_name": not has_preference_name,
        "is_using_default_avatar": True,
        "is_ephemeral": False,
        "background_apps": False,
    }
    for key, value in desired.items():
        if entry.get(key) != value:
            entry[key] = value
            changed = True
    if info_cache.get(profile_dir) != entry:
        info_cache[profile_dir] = entry
        changed = True

    for key in ("profiles_order", "last_active_profiles"):
        updated = _ensure_once(profile_root.get(key), profile_dir)
        if profile_root.get(key) != updated:
            profile_root[key] = updated
            changed = True

    return changed


def repair_profile(
    data_dir: Path | str,
    profile_dir: str = DEFAULT_PROFILE,
    *,
    check_only: bool = False,
    quiet: bool = False,
) -> list[str]:
    """Repair one profile and return the names of changed files."""

    data_dir = Path(data_dir).expanduser()
    profile_path = data_dir / profile_dir
    if not profile_path.is_dir():
        if not quiet:
            print(f"Helium profile guard: profile directory is absent: {profile_path}", file=sys.stderr)
        return []

    with _guard_lock(data_dir):
        if _browser_lock_is_live(data_dir):
            if not quiet:
                print(f"Helium profile guard: browser is running for {data_dir}; skipped", file=sys.stderr)
            return []

        preferences_path = profile_path / "Preferences"
        preferences = _json_object(preferences_path) if preferences_path.exists() else {}
        if preferences is None:
            return []

        local_state_path = data_dir / "Local State"
        if local_state_path.exists():
            local_state = _json_object(local_state_path)
            if local_state is None:
                return []
        else:
            local_state = {}

        changed_files: list[str] = []
        if preferences_path.exists() and _repair_preferences(preferences):
            changed_files.append(str(preferences_path))
        if _repair_local_state(local_state, profile_dir, preferences):
            changed_files.append(str(local_state_path))

        if not check_only:
            if preferences_path.exists() and str(preferences_path) in changed_files:
                _atomic_json_write(preferences_path, preferences)
            if str(local_state_path) in changed_files:
                _atomic_json_write(local_state_path, local_state)

        if changed_files and not quiet:
            verb = "would repair" if check_only else "repaired"
            print(f"Helium profile guard: {verb} {', '.join(changed_files)}")
        return changed_files


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, required=True, help="Helium user-data directory")
    parser.add_argument("--profile-directory", default=DEFAULT_PROFILE)
    parser.add_argument("--check", action="store_true", help="report repairs without writing")
    parser.add_argument("--quiet", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        repair_profile(
            args.data_dir,
            args.profile_directory,
            check_only=args.check,
            quiet=args.quiet,
        )
    except (OSError, RuntimeError, TypeError, ValueError) as exc:
        print(f"Helium profile guard: {exc}", file=sys.stderr)
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
