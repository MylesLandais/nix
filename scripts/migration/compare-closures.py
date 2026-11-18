#!/usr/bin/env python3
"""Compare locally realized Nix closures, preserving output identities and NAR hashes."""

import argparse
from collections import defaultdict
import json
from pathlib import Path
import subprocess


def read_closure(root):
    path = str(Path(root).resolve(strict=True))
    result = subprocess.run(
        ["nix", "path-info", "--recursive", "--json", "--json-format", "1", path],
        check=True,
        capture_output=True,
        text=True,
    )
    closure = json.loads(result.stdout)
    if path not in closure or any(not entry.get("narHash") for entry in closure.values()):
        raise ValueError(f"Missing NAR evidence for {path}")
    return path, closure


def output_identity(path, entry):
    # The store basename includes package version and output suffix when present.
    store_name = Path(path).name.split("-", 1)[1]
    return store_name, entry["narHash"]


def group_changes(closure, paths):
    grouped = defaultdict(list)
    for path in sorted(paths):
        grouped[output_identity(path, closure[path])].append(path)
    return grouped


def compare(old_root, old, new_root, new):
    old_only = group_changes(old, old.keys() - new.keys())
    new_only = group_changes(new, new.keys() - old.keys())
    matches = []
    problems = []
    for path in sorted(old.keys() & new.keys()):
        if old[path]["narHash"] != new[path]["narHash"]:
            problems.append({"path": path, "reason": "different hashes at the same store path"})
    for identity in sorted(old_only.keys() | new_only.keys()):
        before, after = old_only.get(identity, []), new_only.get(identity, [])
        entry = {"name": identity[0], "narHash": identity[1], "before": before, "after": after}
        if len(before) == len(after) == 1:
            matches.append(entry)
        else:
            problems.append(entry)
    if output_identity(old_root, old[old_root]) != output_identity(new_root, new[new_root]):
        problems.append({"reason": "root output identity or content differs"})
    return {"before": old_root, "after": new_root, "paired": matches, "problems": problems}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifests", action="store_true", help="Compare two host/root JSON manifests")
    parser.add_argument("before")
    parser.add_argument("after")
    args = parser.parse_args()
    try:
        if args.manifests:
            def load_manifest(filename):
                grouped = json.loads(Path(filename).read_text())
                return {(host, profile): path for host, roots in grouped.items() for profile, path in roots.items()}
            left, right = load_manifest(args.before), load_manifest(args.after)
            if not left or left.keys() != right.keys():
                raise ValueError("Host/profile sets are empty or differ")
            results = {}
            for host, profile in sorted(left):
                key = (host, profile)
                try:
                    before, old = read_closure(left[key])
                    after, new = read_closure(right[key])
                    result = compare(before, old, after, new)
                except (OSError, ValueError, subprocess.CalledProcessError) as error:
                    result = {"before": left[key], "after": right[key], "problems": [str(error)]}
                results[f"{host}/{profile}"] = result
            print(json.dumps(results, indent=2))
            return int(any(r["problems"] for r in results.values()))
        before, old = read_closure(args.before)
        after, new = read_closure(args.after)
        report = compare(before, old, after, new)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(2, f"Cannot read realized closure evidence: {error}\n")
    print(json.dumps(report, indent=2))
    return int(bool(report["problems"]))


if __name__ == "__main__":
    raise SystemExit(main())
