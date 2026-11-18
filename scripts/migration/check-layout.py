#!/usr/bin/env python3
"""Check module discovery and flag new migration debt in a Git checkout."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import subprocess

BASELINE = Path("docs/migration/layout-debt.json")
RATIONALE = re.compile(r"^\s*# Private (?:helper|data):\s+\S.{8,}", re.MULTILINE)
ARGS = re.compile(r"\b(?:specialArgs|extraSpecialArgs)\b")


def tracked_nix():
    names = subprocess.check_output(["git", "ls-files", "-z", "--", "*.nix"])
    return sorted(Path(name.decode()) for name in names.split(b"\0") if name)


def findings():
    for path in tracked_nix():
        text = path.read_text()
        private = path.parts[0] == "modules" and any(s.startswith("_") for s in path.parts[1:])
        if private and not RATIONALE.search(text):
            yield (str(path), "private-rationale", "")
        if private and re.search(r"(?m)^\s*(?:options(?:\.|\s*=)|imports\s*=|config\s*=\s*lib\.mkIf)", text):
            yield (str(path), "private-module-body", "")
        for line in text.splitlines():
            if line.lstrip().startswith("#"):
                continue
            for field in ARGS.findall(line):
                yield (str(path), field, line.strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--initialize", action="store_true", help="Create the initial exact debt snapshot once")
    args = parser.parse_args()
    current = Counter(findings())
    if args.initialize:
        with BASELINE.open("x") as out:
            out.write("[\n")
            out.write(",\n".join("  " + json.dumps([*key, n]) for key, n in sorted(current.items())))
            out.write("\n]\n")
        return 0
    accepted = Counter({tuple(row[:3]): row[3] for row in json.loads(BASELINE.read_text())})
    base = os.environ.get("BASE_REV")
    if base and set(base) != {"0"}:
        # An upgrade to the rules cannot silently enlarge already tracked debt.
        subprocess.run(["git", "rev-parse", "--verify", base + "^{commit}"], check=True, stdout=subprocess.DEVNULL)
        paths = subprocess.check_output(["git", "ls-tree", "--name-only", base, str(BASELINE)])
        if paths:
            rows = json.loads(subprocess.check_output(["git", "show", f"{base}:{BASELINE}"]))
            ceiling = Counter({tuple(row[:3]): row[3] for row in rows})
            if accepted - ceiling:
                print("Layout debt grew relative to the base revision")
                return 1
    for kind, delta in [("new violation", current - accepted), ("remove resolved debt", accepted - current)]:
        for (path, rule, detail), count in sorted(delta.items()):
            print(f"{path}: {kind}: {rule} ({count}) {detail}")
    return int(current != accepted)


if __name__ == "__main__":
    raise SystemExit(main())
