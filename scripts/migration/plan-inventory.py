#!/usr/bin/env python3
"""Generate the whole-tree migration inventory for an exact Git revision."""

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

# These private expressions return plain values/functions. Every other private
# Nix file at the starting revision contains (or constructs) a lower-level module.
HELPERS = {
    "desktops/hyprland/_config/bindings.nix", "desktops/kali/_packages.nix",
    "flake/_chromium-browsers.nix", "flake/_mk-host.nix", "home/base/_packages.nix",
    "home/prompt/_starship/kanagawa.nix", "hosts/_deploy-nodes.nix",
    "hosts/cerberus/_desktop-layout.nix", "infra/_lib.nix",
    "nixos/gamehacking/_packages.nix", "nixos/overlays/_cursor.nix",
    "nixos/overlays/_pcsx2.nix", "nixos/scbw/_battlenet-game.nix",
    "nixos/scbw/_packages.nix", "hosts/_dell7050/default.nix",
}
WINDOWS_SCRIPTS = {
    "scripts/fetch-driver-pack.sh", "scripts/setup-grub-multiboot-usb.sh",
    "scripts/rustdesk-windows-qemu.sh", "scripts/seal-windows-golden.sh",
    "scripts/test-windows-qemu.sh", "scripts/write-windows-usb.sh",
    "scripts/lib/qemu-spice.sh", "scripts/lib/windows-unattend.sh",
    "docs/cluster/windows-deploy.md", "docs/cluster/grub-multiboot-usb.md",
}
WINDOWS_OUTPUTS = (
    "test-windows-qemu", "boot-windows-golden", "seal-windows-golden", "rustdesk-windows-qemu",
)
RULES = {
    "argument-threading": r"\b(?:extraSpecialArgs|specialArgs)\b",
    "with-scope": r"\bwith\s+(?:pkgs|lib)\s*;",
    "recursive-set": r"\brec\s*\{",
    "ambient-nixpkgs": r"<nixpkgs(?:/[^>]+)?>",
    "shallow-merge-candidate": r"\s//\s",
    "path-reference": r"(?:\bimport\s+|\$\{(?:inputs\.)?self\}/modules/|(?:\s|\[)\.\.?/[\w_-])",
    "source-provenance": r"\bself\b|\bsrc\s*=|\bcleanSource(?:With)?\b|\bfileset\b|\bbuiltins\.path\b",
}
REGISTRATION = re.compile(r"flake\.modules\.(nixos|homeManager)\.([\w-]+)\s*=")
REFERENCE = re.compile(r"(?:\$\{(?:inputs\.)?self\}/|(?<![.\w/])\.\.?/)[\w./-]+")


def git(*args):
    return subprocess.check_output(["git", *args])


def reconcile_modules(revision, rows):
    # Load the requested revision into an isolated index. The caller may have
    # staged work, or may be auditing a revision other than its checkout.
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(tmp, "index")))
        subprocess.run(["git", "read-tree", revision], env=env, check=True)
        listing = subprocess.check_output(["git", "ls-files", "-z", "--", "modules/"], env=env)
    expected = {os.fsdecode(p) for p in listing.split(b"\0") if p}
    actual = [r["source"] for r in rows if r["source"].startswith("modules/")]
    if set(actual) != expected or len(actual) != len(expected):
        raise ValueError(f"Module inventory mismatch: missing {expected - set(actual)}, "
                         f"unexpected {set(actual) - expected}, duplicate rows {len(actual) - len(set(actual))}")
    nix = [Path(p) for p in actual if p.endswith(".nix")]
    return {"tracked": len(actual), "nix": len(nix),
            "private_nix": sum(any(s.startswith("_") for s in p.parts[1:]) for p in nix)}


def destination(path, kind):
    relative = path.relative_to("modules")
    domain, *parts = relative.parts
    if domain == "profiles":
        return Path("modules/roles", *parts)
    if domain in {"hosts", "flake"}:
        base = Path("modules", domain)
    else:
        feature = parts[0].removesuffix(".nix")
        if domain == "home":
            domain = {
                "devtooling": "development", "shelltools": "shell", "prompt": "shell",
                "terminals": "terminal", "hermes": "agents", "hermes-desktop": "agents",
                "hydra-smb": "storage", "ssh-bitwarden": "identity", "firefox": "browser",
                "chromium-helium-prefs": "browser", "workspace-budget-home": "resources",
            }.get(feature, "desktop")
        elif domain == "nixos":
            domain = {
                "chromium-policy": "browser", "firefox-policy": "browser",
                "gamehacking": "gaming", "scbw": "gaming", "pokeforce": "gaming",
                "waydroid-feh": "gaming", "gaming": "gaming", "workspace-budget": "resources",
                "overlays": "packages", "env-packages": "packages", "host-options": "hosts",
                "gpu-unlock": "hardware", "hardware-tuning": "hardware", "nvidia": "hardware",
                "users": "identity", "ssh-keys": "identity", "wifi-profiles": "networking",
                "audio": "desktop", "greeter": "desktop", "theme-data": "desktop",
                "fish-config": "shell",
            }.get(feature, "system")
        elif domain == "desktops":
            domain = "desktop"
        base = Path("modules/aspects", domain)
    if parts == ["default.nix"] and domain == "desktop":
        return Path("modules/roles/desktops.nix")
    if relative.as_posix() == "home/server.nix":
        return Path("modules/roles/server-home.nix")
    if relative.as_posix().startswith("hosts/_dell7050/"):
        if kind == "helper or data":
            return Path("modules/roles/dell7050/_builders.nix")
        return Path("modules/roles/dell7050", *parts[1:])
    if relative.as_posix().startswith("home/terminals/"):
        base = Path("modules/aspects/terminal")
        parts = ["terminals.nix"] if parts[-1] == "default.nix" else [parts[-1]]
    if kind == "private module body":
        parts = [s.removeprefix("_") for s in parts]
        if parts[-1] == "default.nix" and len(parts) > 1:
            parts = parts[:-2] + [parts[-2] + ".nix"]
    if relative.as_posix() == "home/prompt/_starship/kanagawa.nix":
        parts = ["prompt", "starship", "_kanagawa.nix"]
    if relative.as_posix() == "home/devtooling/_kubernetes/skin.yml":
        parts = ["devtooling", "kubernetes", "skin.yml"]
    return base.joinpath(*parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("revision", help="exact revision to inventory")
    revision = git("rev-parse", "--verify", parser.parse_args().revision + "^{commit}").decode().strip()
    # Use the Git tree for both enumeration and reads so a dirty file cannot
    # silently enter a historical snapshot.
    tracked = {Path(x) for x in git("ls-tree", "-rz", "--name-only", revision).decode().split("\0") if x}
    nix_files = sorted(p for p in tracked if p.suffix == ".nix")
    sources = {p: git("show", f"{revision}:{p}").decode() for p in nix_files}
    consumers = defaultdict(set)
    deviations = []
    for p, text in sources.items():
        for line_number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for rule, pattern in RULES.items():
                if re.search(pattern, line):
                    deviations.append({"rule": rule, "source": str(p), "line": line_number})
            for match in REFERENCE.finditer(line):
                ref = match.group().rstrip(".")
                target = Path(ref.split("}/", 1)[1]) if ref.startswith("$") else p.parent / ref
                target = Path(os.path.normpath(target))
                if target not in tracked and target / "default.nix" in tracked:
                    target /= "default.nix"
                if target in tracked:
                    consumers[target].add(str(p))
    rows = []
    for path in sorted(tracked):
        is_windows = str(path) in WINDOWS_SCRIPTS or path.parts[0] == "windows-kit"
        if path.parts[0] != "modules" and path not in sources and not is_windows:
            continue
        text = sources.get(path, "")
        registered = [f"{cls}.{name}" for cls, name in REGISTRATION.findall(text)]
        action = "retain"
        dest = path
        if is_windows:
            kind, cls, feature = "Windows transfer", "standalone", "win-setup"
            action = "transfer"
            dest = Path("warbee/win-setup", str(path).replace("docs/cluster/", "docs/"))
        elif path.parts[0] != "modules":
            kind = {"pkgs": "package recipe", "scripts": "verification harness", "secrets": "recipient declaration"}.get(path.parts[0], "entry point")
            cls, feature = "flake-level", path.stem if kind != "package recipe" else path.parent.name
        else:
            relative = path.relative_to("modules")
            private = any(s.startswith("_") for s in relative.parts)
            if path.suffix != ".nix":
                kind = "asset"
            elif str(relative) in HELPERS:
                kind = "helper or data"
            elif private:
                kind = "private module body"
            else:
                kind = "flake-parts module"
            dest = destination(path, kind)
            feature = dest.parent.name if dest.stem in {"default", "configuration", "nixos"} else dest.stem.lstrip("_")
            cls = ",".join(sorted({x.split(".")[0] for x in registered}))
            if not cls:
                cls = "flake-level" if relative.parts[0] == "flake" or "flake.nixosConfigurations" in text else "nixos"
                if relative.parts[0] == "home" or relative.name == "_home.nix" or relative.parts[:2] in {("desktops", "hyprland"), ("desktops", "niri")}:
                    cls = "homeManager"
            action = "register inline" if kind == "private module body" else ("move" if dest != path else "retain")
            if kind == "private module body":
                deviations.append({"rule": "private-module-body", "source": str(path), "line": 1})
        rows.append({"source": str(path), "feature": feature, "class": cls, "kind": kind,
                     "registrations": registered, "consumers": sorted(consumers[path]),
                     "destination": str(dest), "action": action,
                     "verification": "M-601" if is_windows else str(dest.parent if dest.name == "default.nix" else dest.with_suffix(""))})
    bootstrap = next(r for r in rows if r["source"] == "modules/flake/bootstrap-apps.nix")
    transfers = []
    for name in WINDOWS_OUTPUTS:
        if not re.search(rf"^\s*{re.escape(name)} = pkgs\.writeShellApplication ", sources[Path(bootstrap["source"])], re.M):
            raise ValueError(f"Missing Windows builder {name} in shared bootstrap module")
        outputs = [f"{g}.x86_64-linux.{name}" for g in ("packages", "apps")]
        transfers.append({"binding": name, "action": "transfer", "outputs": outputs,
                          "destination": "warbee/win-setup", "verification": "M-601"})
    bootstrap["reserved_transfers"] = transfers
    transfer_outputs = [o for t in transfers for o in t["outputs"]]
    groups = defaultdict(list)
    for row in rows:
        if row["source"].startswith("modules/") and row["action"] in {"register inline", "move"}:
            target = Path(row["destination"])
            feature = "/".join(target.parts[:4]) if len(target.parts) >= 4 else str(target)
            if target.parts[:3] == ("modules", "aspects", "terminal"):
                feature = "modules/aspects/terminal"
            groups[feature].append(row["source"])
            row["verification"] = feature
    order = sorted(groups, key=lambda key: (key != "modules/aspects/terminal",
                                            key.startswith("modules/hosts/"), key))
    slices = [{"feature": key, "sources": groups[key]} for key in order]
    print(json.dumps({"revision": revision, "module_counts": reconcile_modules(revision, rows),
                      "rows": rows, "candidate_slices": slices, "scan_candidates": deviations,
                      "bootstrap_transfer_outputs": transfer_outputs}, indent=2))


if __name__ == "__main__":
    main()
