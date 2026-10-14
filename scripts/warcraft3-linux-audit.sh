#!/usr/bin/env bash
# Read-only Warcraft III and GPU checks; no Wine prefix mutations.
set -euo pipefail
section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

section 'Wine / Vulkan / Gamescope'
if have wine; then wine --version; else echo 'wine unavailable'; fi
if have gamescope; then gamescope --version 2>&1 | head -n 3 || true; fi
if have gamemoded; then gamemoded -s 2>&1 || true; fi
if have vulkaninfo; then
  vulkaninfo --summary 2>&1 | grep -E 'deviceName|driverName|driverInfo|GPU id|ERROR' | head -n 24 || true
fi
if have nvidia-smi; then
  nvidia-smi --query-gpu=name,driver_version,memory.used,memory.total,utilization.gpu --format=csv,noheader || true
  echo 'GPU clients (VRAM contention matters on a shared 24GB card):'
  nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null || true
fi
if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then
  printf 'nvidia_drm.modeset=%s\n' "$(cat /sys/module/nvidia_drm/parameters/modeset)"
fi

section 'Installation and cache paths'
root="${WC3R_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/games/warcraft3-reforged}"
prefix="$root/prefix"
printf 'Install root: %s\nWine prefix: %s\n' "$root" "$prefix"
for location in "$root" "$prefix" "${XDG_CACHE_HOME:-$HOME/.cache}/warcraft3-reforged"; do
  if [[ -e "$location" ]]; then
    if have findmnt; then findmnt -T "$location" -no TARGET,SOURCE,FSTYPE,OPTIONS || true; fi
    if have du; then du -sh "$location" 2>/dev/null || true; fi
  fi
done
if [[ -f "$prefix/.nixos-game-runtime" ]]; then
  printf 'Runtime marker: %s\n' "$(cat "$prefix/.nixos-game-runtime")"
fi
if [[ -f "$prefix/.nixos-game-dxvk-hashes" ]]; then
  if (cd / && sha256sum --check --quiet "$prefix/.nixos-game-dxvk-hashes") 2>/dev/null; then
    echo 'DXVK prefix DLL hashes: valid'
  else
    echo 'DXVK prefix DLL hashes: stale or mismatched'
  fi
fi
if [[ -d "$prefix/drive_c/windows/system32" ]]; then
  for arch in system32 syswow64; do
    path="$prefix/drive_c/windows/$arch"
    for dll in d3d11.dll dxgi.dll; do
      [[ -f "$path/$dll" ]] &&
        printf 'DXVK candidate %s/%s (%s bytes)\n' "$arch" "$dll" "$(stat -c %s "$path/$dll")"
    done
  done
fi

section 'Game-specific diagnosis'
if have warcraft3-reforged; then
  warcraft3-reforged doctor || true
else
  echo 'warcraft3-reforged launcher absent from PATH'
fi
printf '%s\n' \
  'Compare first launch and second launch times after a clean login.' \
  'Keep DXVK cache enabled; do not delete shader caches between tests.' \
  'Test direct XWayland first, nested Gamescope second, Proton via umu third.' \
  'If W3Champions is installed, test with and without that client before attributing stutters to Reforged.'
