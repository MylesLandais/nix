#!/usr/bin/env python3
"""Report SeaweedFS volume-slot and disk headroom for the local store."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from urllib.request import urlopen

GIB = 1024**3


def fetch_json(url: str) -> dict:
    with urlopen(url, timeout=10) as response:
        return json.load(response)


def build_report(
    master_status: dict,
    volume_status: dict,
    *,
    warning_fraction: float = 0.15,
    pause_fraction: float = 0.10,
    minimum_free_gib: int = 600,
) -> dict:
    topology = master_status.get("Topology", master_status)
    max_volumes = int(topology.get("Max", 0))
    free_volumes = int(topology.get("Free", 0))
    disk_statuses = volume_status.get("DiskStatuses", [])
    disks = [
        {
            "dir": item.get("dir"),
            "free_bytes": int(item.get("free", 0)),
            "used_bytes": int(item.get("used", 0)),
            "all_bytes": int(item.get("all", 0)),
        }
        for item in disk_statuses
    ]
    min_disk_free = min((disk["free_bytes"] for disk in disks), default=0)

    by_collection: dict[str, dict[str, int]] = defaultdict(
        lambda: {"volumes": 0, "bytes": 0, "deleted_bytes": 0, "files": 0}
    )
    for volume in volume_status.get("Volumes", []):
        item = by_collection[str(volume.get("Collection") or "(default)")]
        item["volumes"] += 1
        item["bytes"] += int(volume.get("Size", 0))
        item["deleted_bytes"] += int(volume.get("DeletedByteCount", 0))
        item["files"] += int(volume.get("FileCount", 0))

    warning_slots = max(1, int(max_volumes * warning_fraction))
    pause_slots = max(1, int(max_volumes * pause_fraction))
    pause = (
        max_volumes <= 0
        or free_volumes <= pause_slots
        or min_disk_free <= minimum_free_gib * GIB
    )
    warning = pause or free_volumes <= warning_slots
    return {
        "status": "pause_bulk_writes" if pause else "warning" if warning else "ok",
        "volume_slots": {
            "max": max_volumes,
            "free": free_volumes,
            "free_fraction": free_volumes / max_volumes if max_volumes else 0,
            "warning_at_or_below": warning_slots,
            "pause_at_or_below": pause_slots,
        },
        "minimum_disk_free_bytes": min_disk_free,
        "minimum_disk_free_gib": round(min_disk_free / GIB, 2),
        "pause_disk_threshold_gib": minimum_free_gib,
        "disks": disks,
        "collections": dict(sorted(by_collection.items())),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master-url", default="http://127.0.0.1:9333")
    parser.add_argument("--volume-url", default="http://127.0.0.1:8280")
    parser.add_argument("--warning-fraction", type=float, default=0.15)
    parser.add_argument("--pause-fraction", type=float, default=0.10)
    parser.add_argument("--minimum-free-gib", type=int, default=600)
    args = parser.parse_args()

    try:
        master = fetch_json(f"{args.master_url.rstrip('/')}/dir/status")
        volume = fetch_json(f"{args.volume_url.rstrip('/')}/status")
    except Exception as exc:  # noqa: BLE001 - report status endpoint failures to journald
        print(json.dumps({"status": "unavailable", "error": str(exc)}), file=sys.stderr)
        return 1

    report = build_report(
        master,
        volume,
        warning_fraction=args.warning_fraction,
        pause_fraction=args.pause_fraction,
        minimum_free_gib=args.minimum_free_gib,
    )
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
