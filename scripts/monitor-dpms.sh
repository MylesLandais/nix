#!/usr/bin/env bash
# Compatibility wrapper for the declarative Hyprland workspace recovery service.

set -euo pipefail

if ! command -v hyprland-workspace-recovery >/dev/null 2>&1; then
  echo "hyprland-workspace-recovery is not installed in PATH" >&2
  exit 1
fi

exec hyprland-workspace-recovery "${1:-watch}" "${@:2}"
