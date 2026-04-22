#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[nix-usb-setup]"

TARGET_DRIVE=""
VENTOY_SCRIPT=""
VENTOY_VERSION="1.0.99"

VENTOY_SIZE_GIB=64
LIVE_NIX_SIZE_GIB=500
MIN_DRIVE_BYTES=4000000000000
RESERVE_MIB=0

FORCE_REBUILD=0
SKIP_DISK=0
SKIP_ISO=0
SKIP_REPO_SYNC=0

ISO_URL=""
ISO_NAME=""
ISO_SHA_URL=""

REPO_URL="git@github.com:MylesLandais/nix.git"
REPO_BRANCH="main"

WORK_ROOT="/mnt/nix-usb"
VENTOY_MOUNT="${WORK_ROOT}/ventoy"
LIVE_MOUNT="${WORK_ROOT}/live"
DATA_MOUNT="${WORK_ROOT}/data"
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

Build a Ventoy-first Nix recovery/config USB that provides:
  - Ventoy boot menu for NixOS, Windows, and other ISOs
  - ext4 live_nix workspace for persistent Linux-side tools/configs
  - exFAT images partition for installers and recovery payloads
  - NTFS bulk-data partition for cross-machine storage

Options:
  --device /dev/sdX         Target USB disk (required)
  --ventoy /path/script     Use a local Ventoy2Disk.sh
  --ventoy-version VERSION  Ventoy version to download if needed
  --force-rebuild           Reinstall Ventoy and recreate all partitions
  --skip-disk               Skip disk/format phases and reuse existing layout
  --skip-iso                Skip latest NixOS ISO download/staging
  --skip-repo-sync          Skip git clone/pull on live_nix
  --iso-url URL             Override latest ISO discovery
  --repo-url URL            Override repo URL (default: $REPO_URL)
  --repo-branch BRANCH      Override repo branch (default: $REPO_BRANCH)
  -h, --help                Show this help
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
    lsblk blkid partprobe parted mkfs.ntfs mkfs.exfat mkfs.ext4 mkfs.vfat \
    curl wget tar git rsync grep sed awk udevadm mount umount sync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing command: $cmd" >&2
      missing=1
    fi
  done

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

  log "[$phase] starting"
  if "$@" > >(tee "$logfile") 2>&1; then
    log "[$phase] complete"
  else
    log "[$phase] failed; see $logfile"
    exit 1
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

  bytes="$(lsblk -b -d -n -o SIZE "$TARGET_DRIVE")"
  [[ "$bytes" =~ ^[0-9]+$ ]] || die "Unable to determine size for $TARGET_DRIVE"
  (( bytes >= MIN_DRIVE_BYTES )) || die "$TARGET_DRIVE is smaller than the expected 5TB-class drive."
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
  blkid "$(part_path 1)" "$(part_path 2)" "$(part_path 3)" "$(part_path 4)" "$(part_path 5)" 2>/dev/null || true
}

discover_layout() {
  local p1 p2
  p1="$(part_path 1)"
  p2="$(part_path 2)"

  VENTOY_DATA_PARTNUM=""
  VENTOY_EFI_PARTNUM=""

  [[ "$(lsblk -n -o FSTYPE "$p1" 2>/dev/null || true)" == "exfat" ]] && VENTOY_DATA_PARTNUM="1"
  [[ "$(lsblk -n -o FSTYPE "$p2" 2>/dev/null || true)" == "exfat" ]] && VENTOY_DATA_PARTNUM="2"
  [[ "$(lsblk -n -o LABEL "$p1" 2>/dev/null || true)" == "VTOYEFI" || "$(lsblk -n -o FSTYPE "$p1" 2>/dev/null || true)" == "vfat" ]] && VENTOY_EFI_PARTNUM="1"
  [[ "$(lsblk -n -o LABEL "$p2" 2>/dev/null || true)" == "VTOYEFI" || "$(lsblk -n -o FSTYPE "$p2" 2>/dev/null || true)" == "vfat" ]] && VENTOY_EFI_PARTNUM="2"

  [[ -n "$VENTOY_DATA_PARTNUM" ]] || die "Could not detect Ventoy data partition."
  [[ -n "$VENTOY_EFI_PARTNUM" ]] || die "Could not detect Ventoy EFI partition."

  VENTOY_DATA_PART="$(part_path "$VENTOY_DATA_PARTNUM")"
  VENTOY_EFI_PART="$(part_path "$VENTOY_EFI_PARTNUM")"
  LIVE_PART="$(part_path 3)"
  DATA_PART="$(part_path 4)"
}

layout_ready() {
  discover_layout
  [[ "$(lsblk -n -o LABEL "$LIVE_PART" 2>/dev/null || true)" == "live_nix" ]] &&
    [[ "$(lsblk -n -o LABEL "$DATA_PART" 2>/dev/null || true)" == "persistent_data" ]]
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
}

compute_reserve_mib() {
  local drive_bytes
  drive_bytes="$(lsblk -b -d -n -o SIZE "$TARGET_DRIVE")"
  local drive_mib=$(( drive_bytes / 1024 / 1024 ))
  local ventoy_mib=$(( VENTOY_SIZE_GIB * 1024 ))
  # Subtract Ventoy data partition + 64 MiB for VTOYEFI and alignment
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
  echo "  persistent_data: ${live_end_mib}MiB -> end"

  # Use ---pretend-input-tty so parted accepts "Fix" to any alignment prompts
  # rather than failing hard in -s script mode.
  printf 'Fix\nFix\n' | parted ---pretend-input-tty --align optimal "$TARGET_DRIVE" -- unit MiB \
    mkpart primary ext4 "${live_start_mib}MiB" "${live_end_mib}MiB" \
    mkpart primary "${live_end_mib}MiB" -1

  udevadm settle || true
  partprobe "$TARGET_DRIVE" || true
  sleep 3
  discover_layout
  dump_partition_debug
}

format_partitions() {
  mkfs.ext4 -F -L live_nix "$LIVE_PART"
  mkfs.ntfs -f -L persistent_data "$DATA_PART"
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
  ensure_mountpoint "$DATA_MOUNT"

  umount "$DATA_MOUNT" "$LIVE_MOUNT" "$VENTOY_MOUNT" 2>/dev/null || true

  mount "$VENTOY_DATA_PART" "$VENTOY_MOUNT"
  mount "$LIVE_PART" "$LIVE_MOUNT"
  mount "$DATA_PART" "$DATA_MOUNT"

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
    "$LIVE_MOUNT/tools" \
    "$DATA_MOUNT/backups" \
    "$DATA_MOUNT/media" \
    "$DATA_MOUNT/shared"
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
  log "USB is ready."
  echo "  Ventoy mount: $VENTOY_MOUNT"
  echo "  live_nix:     $LIVE_MOUNT"
  echo "  data:         $DATA_MOUNT"
  echo "  repo path:    ${LIVE_MOUNT}/nix-configs"
  echo "  ISO path:     ${VENTOY_MOUNT}/${ISO_NAME}"
  echo
  echo "Validation steps:"
  echo "  lsblk -f $TARGET_DRIVE"
  echo "  boot the laptop with F12 and use Ventoy to launch the staged NixOS ISO"
  echo "  from the live ISO, mount LABEL=live_nix to access configs and recovery files"
}

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
  log "[disk] skipped by flag"
fi

run_phase mount_partitions mount_partitions
run_phase prepare_layout prepare_layout

if [[ $SKIP_ISO -eq 0 ]]; then
  run_phase stage_iso stage_iso
else
  log "[stage_iso] skipped by flag"
fi

if [[ $SKIP_REPO_SYNC -eq 0 ]]; then
  run_phase sync_repo sync_repo
else
  log "[sync_repo] skipped by flag"
fi

run_phase validate_workspace validate_workspace
run_phase summarize_next_steps summarize_next_steps
