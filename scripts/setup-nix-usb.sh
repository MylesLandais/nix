#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[nix-usb-setup]"

TARGET_DRIVE=""
VENTOY_SCRIPT=""
VENTOY_VERSION="1.0.99"

# Partition sizes — empty means auto-compute from drive size
VENTOY_SIZE_GIB=""
LIVE_NIX_SIZE_GIB=""
HAS_DATA_PART=1       # set to 0 when drive is too small for persistent_data
MIN_DRIVE_GIB=16

RESERVE_MIB=0

FORCE_REBUILD=0
SKIP_DISK=0
SKIP_ISO=0
SKIP_REPO_SYNC=0
DO_NIXOS_INSTALL=0
VERBOSE=0
WIN11_ISO=""

FLAKE_PATH="/home/warby/.config/nixos"
FLAKE_TARGET="lacie"

ISO_URL=""
ISO_NAME=""
ISO_SHA_URL=""

REPO_URL="git@github.com:MylesLandais/nix.git"
REPO_BRANCH="main"

WORK_ROOT="/mnt/nix-usb"
VENTOY_MOUNT="${WORK_ROOT}/ventoy"
LIVE_MOUNT="${WORK_ROOT}/live"
DATA_MOUNT="${WORK_ROOT}/data"
INSTALL_ROOT="${WORK_ROOT}/install"
LOG_DIR=""

VENTOY_DATA_PARTNUM=""
VENTOY_EFI_PARTNUM=""
VENTOY_DATA_PART=""
VENTOY_EFI_PART=""
LIVE_PART=""
DATA_PART=""

usage() {
  cat <<EOF
Usage:
  sudo $SCRIPT_NAME --device /dev/sdX [options]

Build a Ventoy-first NixOS USB and optionally install NixOS onto it.

Disk phases:
  Ventoy boot menu, ext4 live_nix for the NixOS system, optional NTFS
  persistent_data for bulk storage. Sizes are auto-computed from drive
  capacity but can be overridden.

Options:
  --device /dev/sdX         Target USB disk (required)
  --ventoy /path/script     Use a local Ventoy2Disk.sh
  --ventoy-version VERSION  Ventoy version to download if needed (default: $VENTOY_VERSION)
  --ventoy-size GIB         Ventoy partition size (default: auto)
  --live-size GIB           live_nix partition size (default: auto)
  --min-drive-gib N         Minimum acceptable drive size in GiB (default: $MIN_DRIVE_GIB)
  --force-rebuild           Reinstall Ventoy and recreate all partitions
  --skip-disk               Skip disk/format phases and reuse existing layout
  --skip-iso                Skip latest NixOS ISO download/staging
  --skip-repo-sync          Skip git clone/pull on live_nix
  --nixos-install           Run nixos-install after disk setup
  --verbose                 Show full command output (default: summary only, full log in .nix-usb-logs/)
  --flake-path PATH         Flake directory for nixos-install (default: $FLAKE_PATH)
  --flake-target NAME       nixosConfigurations key (default: $FLAKE_TARGET)
  --win11-iso PATH          Stage a local Windows 11 ISO onto the Ventoy partition
  --iso-url URL             Override latest ISO discovery
  --repo-url URL            Override repo URL (default: $REPO_URL)
  --repo-branch BRANCH      Override repo branch (default: $REPO_BRANCH)
  -h, --help                Show this help

Common invocations:

  # Full build from scratch with Windows 11 dual-boot:
  sudo $SCRIPT_NAME --device /dev/sdX --nixos-install --win11-iso /path/to/win11.iso

  # Full build from scratch (NixOS only):
  sudo $SCRIPT_NAME --device /dev/sdX --nixos-install

  # Install NixOS onto an already-formatted drive:
  sudo $SCRIPT_NAME --device /dev/sdX --skip-disk --skip-iso --skip-repo-sync --nixos-install

  # Small drive (200GB) — auto-sizes partitions:
  sudo $SCRIPT_NAME --device /dev/sdX --nixos-install

  # Disk layout only, no NixOS install:
  sudo $SCRIPT_NAME --device /dev/sdX --skip-nixos-install
EOF
}

log() {
  echo "$LOG_PREFIX $*"
}

die() {
  echo "$LOG_PREFIX ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

suggest_tool_shell() {
  cat <<EOF
Missing required tools on this system.

Recommended fallback:
  nix-shell -p parted ntfs3g exfatprogs dosfstools wget gnutar curl git rsync --run \\
    "sudo ./scripts/$SCRIPT_NAME --device /dev/sdX"
EOF
}

check_required_cmds() {
  local missing=0
  local cmd

  for cmd in \
    lsblk blkid partprobe parted mkfs.ext4 mkfs.vfat \
    curl wget tar git rsync grep sed awk udevadm mount umount sync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing command: $cmd" >&2
      missing=1
    fi
  done

  # ntfs and exfat only needed when creating those filesystems
  if [[ $HAS_DATA_PART -eq 1 ]] && ! command -v mkfs.ntfs >/dev/null 2>&1; then
    echo "Missing command: mkfs.ntfs (needed for persistent_data)" >&2
    missing=1
  fi

  if [[ $missing -ne 0 ]]; then
    echo >&2
    suggest_tool_shell >&2
    exit 1
  fi
}

init_log_dir() {
  LOG_DIR="${PWD}/.nix-usb-logs/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$LOG_DIR"
  log "Logs: $LOG_DIR"
}

run_phase() {
  local phase="$1"
  shift
  local logfile="${LOG_DIR}/${phase}.log"

  printf "%s [%-20s] ... " "$LOG_PREFIX" "$phase"
  if [[ $VERBOSE -eq 1 ]]; then
    echo
    if "$@" 2>&1 | tee "$logfile"; then
      log "[$phase] done"
    else
      echo "FAILED — see $logfile" >&2
      exit 1
    fi
  else
    if "$@" > "$logfile" 2>&1; then
      echo "done"
    else
      echo "FAILED"
      echo "$LOG_PREFIX See $logfile for details:" >&2
      tail -20 "$logfile" >&2
      exit 1
    fi
  fi
}

patch_ventoy_bundle() {
  local ventoy_dir
  local arch_dir

  ventoy_dir="$(cd "$(dirname "$VENTOY_SCRIPT")" && pwd)"
  arch_dir="$ventoy_dir/tool/x86_64"

  [[ -d "$arch_dir" ]] || return 0

  rm -f "$arch_dir/mkexfatfs" "$arch_dir/mkexfatfs.xz"

  cat > "$arch_dir/mkexfatfs" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

label=""
device=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -V|--version)
      mkfs.exfat -V >/dev/null 2>&1 || true
      echo "mkexfatfs shim using mkfs.exfat"
      exit 0
      ;;
    -n)
      label="${2:-}"
      shift 2
      ;;
    -s)
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      device="$1"
      shift
      ;;
  esac
done

[[ -n "$device" ]] || exit 1

if [[ -n "$label" ]]; then
  exec mkfs.exfat -L "$label" "$device"
else
  exec mkfs.exfat "$device"
fi
EOF
  chmod +x "$arch_dir/mkexfatfs"
}

resolve_ventoy_script() {
  if [[ -n "$VENTOY_SCRIPT" ]]; then
    [[ -x "$VENTOY_SCRIPT" ]] || die "Ventoy script is not executable: $VENTOY_SCRIPT"
    return 0
  fi

  if [[ -x "./ventoy-${VENTOY_VERSION}/Ventoy2Disk.sh" ]]; then
    VENTOY_SCRIPT="./ventoy-${VENTOY_VERSION}/Ventoy2Disk.sh"
    return 0
  fi

  require_cmd wget
  require_cmd tar

  local archive="ventoy-${VENTOY_VERSION}-linux.tar.gz"
  local url="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/${archive}"

  log "Downloading Ventoy ${VENTOY_VERSION}"
  wget -q "$url" -O "$archive"
  tar -xf "$archive"

  VENTOY_SCRIPT="./ventoy-${VENTOY_VERSION}/Ventoy2Disk.sh"
  [[ -x "$VENTOY_SCRIPT" ]] || die "Failed to prepare Ventoy script at $VENTOY_SCRIPT"
}

discover_latest_iso() {
  if [[ -n "$ISO_URL" ]]; then
    ISO_NAME="$(basename "$ISO_URL")"
    ISO_SHA_URL="${ISO_URL}.sha256"
    return 0
  fi

  ISO_URL="https://channels.nixos.org/nixos-25.11/latest-nixos-graphical-x86_64-linux.iso"
  ISO_NAME="$(basename "$ISO_URL")"
  ISO_SHA_URL="${ISO_URL}.sha256"
}

get_drive_facts() {
  local bytes
  local drive_gib

  bytes="$(lsblk -b -d -n -o SIZE "$TARGET_DRIVE")"
  [[ "$bytes" =~ ^[0-9]+$ ]] || die "Unable to determine size for $TARGET_DRIVE"

  drive_gib=$(( bytes / 1024 / 1024 / 1024 ))
  (( drive_gib >= MIN_DRIVE_GIB )) || die "$TARGET_DRIVE is ${drive_gib} GiB — minimum is ${MIN_DRIVE_GIB} GiB."

  # Auto-compute sizes if not set by flags
  if [[ -z "$VENTOY_SIZE_GIB" || -z "$LIVE_NIX_SIZE_GIB" ]]; then
    compute_sizes "$drive_gib"
  fi

  log "Drive: ${drive_gib} GiB"
  log "Layout: ventoy=${VENTOY_SIZE_GIB} GiB, live_nix=${LIVE_NIX_SIZE_GIB} GiB, persistent_data=$(
    if [[ $HAS_DATA_PART -eq 1 ]]; then
      echo "remaining (~$(( drive_gib - VENTOY_SIZE_GIB - LIVE_NIX_SIZE_GIB )) GiB)"
    else
      echo "none (drive too small)"
    fi
  )"
  echo
  read -r -p "Proceed with this layout on $TARGET_DRIVE? [yes/N] " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || exit 1
}

compute_sizes() {
  local drive_gib="$1"

  if [[ -n "$VENTOY_SIZE_GIB" && -n "$LIVE_NIX_SIZE_GIB" ]]; then
    # Both explicitly set — validate there's room
    local total=$(( VENTOY_SIZE_GIB + LIVE_NIX_SIZE_GIB ))
    local remaining=$(( drive_gib - total ))
    if (( remaining < 1 )); then
      die "Not enough space: ventoy=${VENTOY_SIZE_GIB} GiB + live_nix=${LIVE_NIX_SIZE_GIB} GiB exceeds drive (${drive_gib} GiB)."
    fi
    HAS_DATA_PART=$(( remaining >= 2 ? 1 : 0 ))
    return
  fi

  # Auto-size tiers
  if (( drive_gib < 32 )); then
    VENTOY_SIZE_GIB=4
    LIVE_NIX_SIZE_GIB=$(( drive_gib - VENTOY_SIZE_GIB - 1 ))
    HAS_DATA_PART=0
  elif (( drive_gib < 128 )); then
    VENTOY_SIZE_GIB=8
    local remaining=$(( drive_gib - VENTOY_SIZE_GIB ))
    LIVE_NIX_SIZE_GIB=$(( remaining * 60 / 100 ))
    HAS_DATA_PART=1
  elif (( drive_gib < 512 )); then
    VENTOY_SIZE_GIB=20
    local remaining=$(( drive_gib - VENTOY_SIZE_GIB ))
    LIVE_NIX_SIZE_GIB=$(( remaining * 60 / 100 ))
    HAS_DATA_PART=1
  else
    VENTOY_SIZE_GIB=64
    LIVE_NIX_SIZE_GIB=500
    HAS_DATA_PART=1
  fi
}

drive_basename() {
  basename "$TARGET_DRIVE"
}

part_path() {
  local num="$1"
  local base
  base="$(drive_basename)"
  case "$base" in
    nvme*|mmcblk*|loop*|nbd*|zd*)
      echo "${TARGET_DRIVE}p${num}"
      ;;
    *)
      echo "${TARGET_DRIVE}${num}"
      ;;
  esac
}

dump_partition_debug() {
  log "Partition table snapshot:"
  parted -s "$TARGET_DRIVE" unit MiB print || true
  echo
  log "lsblk snapshot:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "$TARGET_DRIVE" || true
  echo
  log "blkid snapshot:"
  blkid "$(part_path 1)" "$(part_path 2)" "$(part_path 3)" "$(part_path 4)" 2>/dev/null || true
}

discover_layout() {
  local p1 p2

  p1="$(part_path 1)"
  p2="$(part_path 2)"

  VENTOY_DATA_PARTNUM=""
  VENTOY_EFI_PARTNUM=""

  [[ "$(lsblk -n -o FSTYPE "$p1" 2>/dev/null || true)" == "exfat" ]] && VENTOY_DATA_PARTNUM="1"
  [[ "$(lsblk -n -o FSTYPE "$p2" 2>/dev/null || true)" == "exfat" ]] && VENTOY_DATA_PARTNUM="2"
  [[ "$(lsblk -n -o LABEL "$p1" 2>/dev/null || true)" == "VTOYEFI" || \
     "$(lsblk -n -o FSTYPE "$p1" 2>/dev/null || true)" == "vfat" ]] && VENTOY_EFI_PARTNUM="1"
  [[ "$(lsblk -n -o LABEL "$p2" 2>/dev/null || true)" == "VTOYEFI" || \
     "$(lsblk -n -o FSTYPE "$p2" 2>/dev/null || true)" == "vfat" ]] && VENTOY_EFI_PARTNUM="2"

  [[ -n "$VENTOY_DATA_PARTNUM" ]] || die "Could not detect Ventoy data partition."
  [[ -n "$VENTOY_EFI_PARTNUM" ]] || die "Could not detect Ventoy EFI partition."

  VENTOY_DATA_PART="$(part_path "$VENTOY_DATA_PARTNUM")"
  VENTOY_EFI_PART="$(part_path "$VENTOY_EFI_PARTNUM")"
  LIVE_PART="$(part_path 3)"

  if [[ $HAS_DATA_PART -eq 1 ]]; then
    DATA_PART="$(part_path 4)"
  else
    DATA_PART=""
  fi
}

layout_ready() {
  discover_layout
  local live_label
  live_label="$(lsblk -n -o LABEL "$LIVE_PART" 2>/dev/null || true)"
  if [[ "$live_label" != "live_nix" ]]; then
    return 1
  fi
  if [[ $HAS_DATA_PART -eq 1 && -n "$DATA_PART" ]]; then
    [[ "$(lsblk -n -o LABEL "$DATA_PART" 2>/dev/null || true)" == "persistent_data" ]]
  fi
}

prepare_tools() {
  check_required_cmds
  get_drive_facts
  resolve_ventoy_script
  patch_ventoy_bundle
  discover_latest_iso
  log "Target drive: $TARGET_DRIVE"
  log "Ventoy script: $VENTOY_SCRIPT"
  log "ISO URL: $ISO_URL"
  log "Repo: $REPO_URL ($REPO_BRANCH)"
  if [[ $DO_NIXOS_INSTALL -eq 1 ]]; then
    log "NixOS install: ${FLAKE_PATH}#${FLAKE_TARGET}"
  fi
}

compute_reserve_mib() {
  local drive_bytes
  drive_bytes="$(lsblk -b -d -n -o SIZE "$TARGET_DRIVE")"
  local drive_mib=$(( drive_bytes / 1024 / 1024 ))
  local ventoy_mib=$(( VENTOY_SIZE_GIB * 1024 ))
  # Reserve everything after the Ventoy data partition; Ventoy writes its EFI
  # partition into this reserved space, then we add our own partitions after.
  RESERVE_MIB=$(( drive_mib - ventoy_mib - 64 ))
  log "Drive: ${drive_mib} MiB, Ventoy data: ${ventoy_mib} MiB, reserve: ${RESERVE_MIB} MiB"
}

install_ventoy() {
  compute_reserve_mib
  "$VENTOY_SCRIPT" -I -g -r "$RESERVE_MIB" "$TARGET_DRIVE"
  udevadm settle || true
  partprobe "$TARGET_DRIVE" || true
  sleep 3
  discover_layout
  dump_partition_debug
}

create_extra_partitions() {
  local vtoyefi_end_mib live_start_mib live_end_mib

  vtoyefi_end_mib="$(
    parted -sm "$TARGET_DRIVE" unit MiB print 2>/dev/null |
      awk -F: 'NR>2 {gsub("MiB","",$3); end=$3} END {print int(end)}'
  )"
  [[ -n "$vtoyefi_end_mib" ]] || die "Could not determine end of Ventoy partitions."

  live_start_mib=$(( vtoyefi_end_mib + 1 ))
  live_end_mib=$(( live_start_mib + LIVE_NIX_SIZE_GIB * 1024 ))

  log "Partition boundaries:"
  echo "  live_nix:        ${live_start_mib}MiB -> ${live_end_mib}MiB"

  if [[ $HAS_DATA_PART -eq 1 ]]; then
    echo "  persistent_data: ${live_end_mib}MiB -> end"
    printf 'Fix\nFix\n' | parted ---pretend-input-tty --align optimal "$TARGET_DRIVE" -- unit MiB \
      mkpart primary ext4 "${live_start_mib}MiB" "${live_end_mib}MiB" \
      mkpart primary "${live_end_mib}MiB" -1
  else
    echo "  persistent_data: skipped (drive too small)"
    printf 'Fix\nFix\n' | parted ---pretend-input-tty --align optimal "$TARGET_DRIVE" -- unit MiB \
      mkpart primary ext4 "${live_start_mib}MiB" -1
  fi

  udevadm settle || true
  partprobe "$TARGET_DRIVE" || true
  sleep 3
  discover_layout
  dump_partition_debug
}

format_partitions() {
  mkfs.ext4 -F -L live_nix "$LIVE_PART"
  if [[ $HAS_DATA_PART -eq 1 && -n "$DATA_PART" ]]; then
    mkfs.ntfs -f -L persistent_data "$DATA_PART"
  fi
  udevadm settle || true
  partprobe "$TARGET_DRIVE" || true
  dump_partition_debug
}

ensure_mountpoint() {
  mkdir -p "$1"
}

mount_partitions() {
  ensure_mountpoint "$VENTOY_MOUNT"
  ensure_mountpoint "$LIVE_MOUNT"

  umount "$DATA_MOUNT" "$LIVE_MOUNT" "$VENTOY_MOUNT" 2>/dev/null || true

  mount "$VENTOY_DATA_PART" "$VENTOY_MOUNT"
  mount "$LIVE_PART" "$LIVE_MOUNT"

  if [[ $HAS_DATA_PART -eq 1 && -n "$DATA_PART" ]]; then
    ensure_mountpoint "$DATA_MOUNT"
    mount "$DATA_PART" "$DATA_MOUNT" || log "Warning: persistent_data mount failed — continuing"
  fi

  log "Mounts:"
  mount | grep -E "${VENTOY_MOUNT}|${LIVE_MOUNT}|${DATA_MOUNT}" || true
}

stage_iso() {
  local iso_path="${VENTOY_MOUNT}/${ISO_NAME}"
  local sha_path="${iso_path}.sha256"

  if [[ -f "$iso_path" ]]; then
    log "ISO already present: $iso_path"
  else
    curl -fL --output "$iso_path" "$ISO_URL"
  fi

  if [[ -n "$ISO_SHA_URL" ]]; then
    curl -fL --output "$sha_path" "$ISO_SHA_URL" || true
  fi

  sync
  ls -lh "$iso_path" "$sha_path" 2>/dev/null || true
}

prepare_layout() {
  mkdir -p \
    "$LIVE_MOUNT/nix-configs" \
    "$LIVE_MOUNT/recovery" \
    "$LIVE_MOUNT/tools"

  if [[ $HAS_DATA_PART -eq 1 ]] && mountpoint -q "$DATA_MOUNT" 2>/dev/null; then
    mkdir -p \
      "$DATA_MOUNT/backups" \
      "$DATA_MOUNT/media" \
      "$DATA_MOUNT/shared"
  fi
}

sync_repo() {
  local repo_path="${LIVE_MOUNT}/nix-configs"

  if [[ -d "${repo_path}/.git" ]]; then
    git -C "$repo_path" fetch origin
    git -C "$repo_path" pull --ff-only origin "$REPO_BRANCH"
  else
    rm -rf "$repo_path"
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$repo_path"
  fi
}

nixos_install() {
  [[ -d "$FLAKE_PATH" ]] || die "Flake path not found: $FLAKE_PATH"
  command -v nixos-install >/dev/null 2>&1 || die "nixos-install not found. Are you running on NixOS?"

  mkdir -p "$INSTALL_ROOT" "$INSTALL_ROOT/boot"

  # Trap to always unmount on exit
  cleanup_install() {
    log "Unmounting install root..."
    umount -R "$INSTALL_ROOT" 2>/dev/null || true
  }
  trap cleanup_install EXIT

  log "Mounting live_nix at $INSTALL_ROOT"
  mountpoint -q "$INSTALL_ROOT" || mount "$LIVE_PART" "$INSTALL_ROOT"

  log "Mounting VTOYEFI at $INSTALL_ROOT/boot"
  mountpoint -q "$INSTALL_ROOT/boot" || mount "$VENTOY_EFI_PART" "$INSTALL_ROOT/boot"

  log "Running nixos-install --flake ${FLAKE_PATH}#${FLAKE_TARGET} --root $INSTALL_ROOT"
  log "(this takes 10-20 min — output always shown)"
  nixos-install \
    --flake "${FLAKE_PATH}#${FLAKE_TARGET}" \
    --root "$INSTALL_ROOT" \
    --no-root-passwd \
    2>&1 | tee "${LOG_DIR}/nixos-install.log"

  # Add Ventoy chainload entry while /boot is still mounted
  add_ventoy_boot_entry

  trap - EXIT
  cleanup_install

  cat <<EOF

NixOS installed. Before booting:

  1. Drop the Hermes API key (if not already done):
       sudo mkdir -p /mnt/nix-usb/data/secrets
       echo 'ANTHROPIC_API_KEY=sk-ant-...' | sudo tee /mnt/nix-usb/data/secrets/hermes.env
       sudo chmod 600 /mnt/nix-usb/data/secrets/hermes.env

  2. Eject the drive:
       sudo umount -R /mnt/nix-usb

  3. Boot the target machine — press F12 at POST, select the UEFI USB entry.
     Secure Boot must be OFF. UEFI mode required (not Legacy/CSM).
     You should land directly in Hyprland.

  4. After first boot, rebuild to apply any pending changes:
       sudo nixos-rebuild switch --flake /nix-configs#$FLAKE_TARGET

  5. Regenerate hardware config on the target machine and commit:
       nixos-generate-config --show-hardware-config > /nix-configs/hosts/$FLAKE_TARGET/hardware-configuration.nix
       git -C /nix-configs commit -am "feat(lacie): update hardware-configuration.nix"

EOF
}

stage_win11_iso() {
  if [[ -z "$WIN11_ISO" ]]; then
    log "[win11] no --win11-iso provided; skipping"
    return 0
  fi

  [[ -f "$WIN11_ISO" ]] || die "Win11 ISO not found: $WIN11_ISO"

  local dest="${VENTOY_MOUNT}/$(basename "$WIN11_ISO")"

  if [[ -f "$dest" ]]; then
    log "[win11] already staged: $dest"
    return 0
  fi

  log "[win11] staging $(basename "$WIN11_ISO") to Ventoy partition..."
  rsync --progress "$WIN11_ISO" "$dest"
  sync
  log "[win11] done"
}

add_ventoy_boot_entry() {
  local entry_dir="${INSTALL_ROOT}/boot/loader/entries"
  local entry_file="${entry_dir}/ventoy.conf"

  [[ -d "$INSTALL_ROOT/boot" ]] || {
    log "[ventoy-entry] INSTALL_ROOT/boot not mounted; skipping"
    return 0
  }

  # Find Ventoy's grub binary — it survives nixos-install's BOOTX64.EFI overwrite
  local ventoy_efi=""
  for candidate in \
    "/EFI/BOOT/grubx64.efi" \
    "/EFI/ventoy/ventoy_x64.efi" \
    "/EFI/BOOT/mmx64.efi"; do
    if [[ -f "${INSTALL_ROOT}/boot${candidate}" ]]; then
      ventoy_efi="$candidate"
      break
    fi
  done

  if [[ -z "$ventoy_efi" ]]; then
    log "[ventoy-entry] WARNING: no Ventoy EFI binary found — boot entry not added"
    log "[ventoy-entry] Files on VTOYEFI:"
    find "${INSTALL_ROOT}/boot/EFI" -type f 2>/dev/null | sort || true
    return 0
  fi

  log "[ventoy-entry] Ventoy binary: $ventoy_efi"
  mkdir -p "$entry_dir"

  cat > "$entry_file" <<EOF
title   Ventoy (Windows 11 / ISO Boot Menu)
efi     ${ventoy_efi}
EOF

  log "[ventoy-entry] wrote $entry_file"
}

validate_workspace() {
  log "Workspace validation:"
  test -d "${LIVE_MOUNT}/nix-configs" || die "Missing nix-configs directory on live_nix."
  test -d "${LIVE_MOUNT}/recovery" || die "Missing recovery directory on live_nix."
  test -f "${VENTOY_MOUNT}/${ISO_NAME}" || die "Missing staged ISO on Ventoy partition."
  if [[ -d "${LIVE_MOUNT}/nix-configs/.git" ]]; then
    git -C "${LIVE_MOUNT}/nix-configs" rev-parse --abbrev-ref HEAD
    git -C "${LIVE_MOUNT}/nix-configs" status --short
  fi
}

summarize_next_steps() {
  log "USB disk is ready."
  echo "  Ventoy mount: $VENTOY_MOUNT"
  echo "  live_nix:     $LIVE_MOUNT"
  if [[ $HAS_DATA_PART -eq 1 ]]; then
    echo "  data:         $DATA_MOUNT"
  fi
  echo "  repo path:    ${LIVE_MOUNT}/nix-configs"
  echo "  ISO path:     ${VENTOY_MOUNT}/${ISO_NAME}"
  echo
  if [[ $DO_NIXOS_INSTALL -eq 0 ]]; then
    echo "To install NixOS onto this drive, run:"
    echo "  sudo $SCRIPT_NAME --device $TARGET_DRIVE --skip-disk --skip-iso --skip-repo-sync --nixos-install"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      TARGET_DRIVE="${2:-}"
      shift 2
      ;;
    --ventoy)
      VENTOY_SCRIPT="${2:-}"
      shift 2
      ;;
    --ventoy-version)
      VENTOY_VERSION="${2:-}"
      shift 2
      ;;
    --ventoy-size)
      VENTOY_SIZE_GIB="${2:-}"
      shift 2
      ;;
    --live-size)
      LIVE_NIX_SIZE_GIB="${2:-}"
      shift 2
      ;;
    --min-drive-gib)
      MIN_DRIVE_GIB="${2:-}"
      shift 2
      ;;
    --force-rebuild)
      FORCE_REBUILD=1
      shift
      ;;
    --skip-disk)
      SKIP_DISK=1
      shift
      ;;
    --skip-iso)
      SKIP_ISO=1
      shift
      ;;
    --skip-repo-sync)
      SKIP_REPO_SYNC=1
      shift
      ;;
    --nixos-install)
      DO_NIXOS_INSTALL=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --win11-iso)
      WIN11_ISO="${2:-}"
      shift 2
      ;;
    --skip-nixos-install)
      DO_NIXOS_INSTALL=0
      shift
      ;;
    --flake-path)
      FLAKE_PATH="${2:-}"
      shift 2
      ;;
    --flake-target)
      FLAKE_TARGET="${2:-}"
      shift 2
      ;;
    --iso-url)
      ISO_URL="${2:-}"
      shift 2
      ;;
    --repo-url)
      REPO_URL="${2:-}"
      shift 2
      ;;
    --repo-branch)
      REPO_BRANCH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ $EUID -eq 0 ]] || die "Run this script with sudo."
[[ -n "$TARGET_DRIVE" ]] || die "--device is required."
[[ -b "$TARGET_DRIVE" ]] || die "Target is not a block device: $TARGET_DRIVE"

init_log_dir
run_phase prepare_tools prepare_tools

if [[ $SKIP_DISK -eq 0 ]]; then
  if [[ $FORCE_REBUILD -eq 1 ]] || ! layout_ready; then
    run_phase install_ventoy install_ventoy
    run_phase create_extra_partitions create_extra_partitions
    run_phase format_partitions format_partitions
  else
    log "[disk] existing layout detected; skipping disk phases"
    dump_partition_debug > "${LOG_DIR}/disk-skip.log" 2>&1 || true
  fi
else
  discover_layout
  log "[disk] skipped by flag"
fi

run_phase mount_partitions mount_partitions
run_phase prepare_layout prepare_layout

if [[ $SKIP_ISO -eq 0 ]]; then
  run_phase stage_iso stage_iso
else
  log "[stage_iso] skipped by flag"
fi

run_phase stage_win11_iso stage_win11_iso

if [[ $SKIP_REPO_SYNC -eq 0 ]]; then
  run_phase sync_repo sync_repo
else
  log "[sync_repo] skipped by flag"
fi

if [[ $DO_NIXOS_INSTALL -eq 1 ]]; then
  run_phase nixos_install nixos_install
else
  run_phase validate_workspace validate_workspace
  run_phase summarize_next_steps summarize_next_steps
fi
