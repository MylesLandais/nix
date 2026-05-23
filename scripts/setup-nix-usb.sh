#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="[nix-usb-setup]"

TARGET_DRIVE=""

# Partition sizes
EFI_SIZE_GIB=1        # FAT32 ESP — fixed
ISOS_SIZE_GIB=63      # exFAT ISO partition — overridable via --isos-size
LIVE_NIX_SIZE_GIB=""  # auto-computed or overridden via --live-size (only used on fresh installs)
HAS_DATA_PART=1       # set to 0 when drive is too small for persistent_data
MIN_DRIVE_GIB=16

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
EFI_MOUNT="${WORK_ROOT}/efi"
ISOS_MOUNT="${WORK_ROOT}/isos"
LIVE_MOUNT="${WORK_ROOT}/live"
DATA_MOUNT="${WORK_ROOT}/data"
INSTALL_ROOT="${WORK_ROOT}/install"
LOG_DIR=""

EFI_PART=""
ISOS_PART=""
LIVE_PART=""
DATA_PART=""

usage() {
  cat <<EOF
Usage:
  sudo $SCRIPT_NAME --device /dev/sdX [options]

Build a GRUB-first NixOS USB and optionally install NixOS onto it.

Disk layout (p1 and p2 only — p3/p4 are preserved if they exist):
  p1  LACIE_EFI   FAT32  ${EFI_SIZE_GIB} GiB   — GRUB EFI + theme
  p2  lacie_isos  exFAT  ${ISOS_SIZE_GIB} GiB   — ISO files for loopback boot
  p3  live_nix    ext4   500 GiB  — NixOS system root (preserved)
  p4  persistent_data NTFS  rest   — bulk storage (preserved)

Options:
  --device /dev/sdX         Target USB disk (required)
  --isos-size GIB           ISO partition size in GiB (default: $ISOS_SIZE_GIB)
  --live-size GIB           live_nix size GiB — only used if creating p3 fresh (default: auto)
  --min-drive-gib N         Minimum acceptable drive size in GiB (default: $MIN_DRIVE_GIB)
  --force-rebuild           Recreate p1+p2 even if layout looks correct
  --skip-disk               Skip all disk/format phases and reuse existing layout
  --skip-iso                Skip latest NixOS ISO download/staging
  --skip-repo-sync          Skip git clone/pull on live_nix
  --nixos-install           Run nixos-install after disk setup
  --verbose                 Show full command output (default: summary only, full log in .nix-usb-logs/)
  --flake-path PATH         Flake directory for nixos-install (default: $FLAKE_PATH)
  --flake-target NAME       nixosConfigurations key (default: $FLAKE_TARGET)
  --win11-iso PATH          Stage a Windows ISO onto the lacie_isos partition
  --iso-url URL             Override latest NixOS ISO URL
  --repo-url URL            Override repo URL (default: $REPO_URL)
  --repo-branch BRANCH      Override repo branch (default: $REPO_BRANCH)
  -h, --help                Show this help

Common invocations:

  # Migrate existing Ventoy LaCie to GRUB layout (preserves p3/p4 data):
  sudo $SCRIPT_NAME --device /dev/sdX

  # Full build from scratch (NixOS only):
  sudo $SCRIPT_NAME --device /dev/sdX --nixos-install

  # Install NixOS onto an already-formatted drive:
  sudo $SCRIPT_NAME --device /dev/sdX --skip-disk --skip-iso --skip-repo-sync --nixos-install

  # Disk layout only, no NixOS install:
  sudo $SCRIPT_NAME --device /dev/sdX
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
  nix-shell -p parted gptfdisk exfatprogs dosfstools grub2 ntfs3g wget curl git rsync --run \\
    "sudo -E ./scripts/$SCRIPT_NAME --device /dev/sdX"
EOF
}

check_required_cmds() {
  local missing=0
  local cmd

  for cmd in \
    lsblk blkid partprobe sgdisk mkfs.fat mkfs.exfat mkfs.ext4 \
    grub-install curl wget git rsync grep sed awk udevadm mount umount sync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing command: $cmd" >&2
      missing=1
    fi
  done

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

partition_disk() {
  local p3_exists=0
  local p4_exists=0

  # Check whether p3/p4 already exist (they carry live_nix and persistent_data data)
  lsblk "$(part_path 3)" &>/dev/null && p3_exists=1 || true
  lsblk "$(part_path 4)" &>/dev/null && p4_exists=1 || true

  # Ensure GPT exists (safe no-op if already present)
  if ! sgdisk -p "$TARGET_DRIVE" &>/dev/null; then
    sgdisk -o "$TARGET_DRIVE"
  fi

  # Remove Ventoy partitions (p1, p2) — leaves p3/p4 untouched
  sgdisk -d 1 "$TARGET_DRIVE" 2>/dev/null || true
  sgdisk -d 2 "$TARGET_DRIVE" 2>/dev/null || true
  udevadm settle || true; sleep 1

  # Create p1: FAT32 ESP (1 GiB)
  sgdisk -n 1:2048:+${EFI_SIZE_GIB}G -t 1:ef00 -c 1:LACIE_EFI "$TARGET_DRIVE"
  # Create p2: exFAT ISO partition (fills space previously used by Ventoy data)
  sgdisk -n 2:0:+${ISOS_SIZE_GIB}G -t 2:0700 -c 2:lacie_isos "$TARGET_DRIVE"

  # Create p3/p4 only on a fresh drive where they do not yet exist
  if [[ $p3_exists -eq 0 ]]; then
    [[ -n "$LIVE_NIX_SIZE_GIB" ]] || die "live_nix size unknown — pass --live-size GIB for a fresh install."
    sgdisk -n 3:0:+${LIVE_NIX_SIZE_GIB}G -t 3:8300 -c 3:live_nix "$TARGET_DRIVE"
    log "Created p3 (live_nix, ${LIVE_NIX_SIZE_GIB} GiB)"
  else
    log "p3 (live_nix) already present — not touched"
  fi

  if [[ $HAS_DATA_PART -eq 1 && $p4_exists -eq 0 ]]; then
    sgdisk -n 4:0:0 -t 4:0700 -c 4:persistent_data "$TARGET_DRIVE"
    log "Created p4 (persistent_data)"
  elif [[ $p4_exists -eq 1 ]]; then
    log "p4 (persistent_data) already present — not touched"
  fi

  udevadm settle || true
  partprobe "$TARGET_DRIVE" || true
  sleep 3
  discover_layout
  dump_partition_debug
}

format_efi_isos() {
  mkfs.fat -F 32 -n LACIE_EFI "$EFI_PART"
  mkfs.exfat -n lacie_isos "$ISOS_PART"
  # p3 (live_nix) and p4 (persistent_data) are intentionally NOT reformatted
  udevadm settle || true
  partprobe "$TARGET_DRIVE" || true
  dump_partition_debug
}

install_grub() {
  local efi_mount="${WORK_ROOT}/grub-install-tmp"
  mkdir -p "$efi_mount"
  mount "$EFI_PART" "$efi_mount"

  grub-install \
    --target=x86_64-efi \
    --efi-directory="$efi_mount" \
    --boot-directory="$efi_mount/boot" \
    --removable \
    --no-nvram

  # Bootstrap grub.cfg for pre-NixOS ISO booting.
  # After nixos-install runs, NixOS replaces this with the declarative config
  # (including the Kanagawa theme and proper extraEntries).
  mkdir -p "$efi_mount/boot/grub"
  cat > "$efi_mount/boot/grub/grub.cfg" <<'GRUBCFG'
set timeout=30
set default=0

insmod part_gpt
insmod fat
insmod exfat
insmod loopback
insmod iso9660
insmod ext2

search --no-floppy --label --set=isopart lacie_isos

menuentry "Home Office Installer (NixOS)" {
  loopback loop ($isopart)/home-office-installer.iso
  set root=(loop)
  configfile /boot/grub/grub.cfg
}

menuentry "NixOS Graphical Live" {
  loopback loop ($isopart)/nixos-latest-graphical.iso
  set root=(loop)
  configfile /boot/grub/grub.cfg
}

menuentry "Kali Linux Live" {
  loopback loop ($isopart)/kali-live-latest.iso
  set root=(loop)
  configfile /boot/grub/grub.cfg
}

menuentry "Reboot"   { reboot }
menuentry "Shutdown" { halt }
GRUBCFG

  sync
  umount "$efi_mount"
  rmdir "$efi_mount"
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

  if [[ -z "$LIVE_NIX_SIZE_GIB" ]]; then
    compute_sizes "$drive_gib"
  fi

  local boot_total=$(( EFI_SIZE_GIB + ISOS_SIZE_GIB ))
  log "Drive: ${drive_gib} GiB"
  log "Layout: EFI=${EFI_SIZE_GIB} GiB, ISOs=${ISOS_SIZE_GIB} GiB, live_nix=${LIVE_NIX_SIZE_GIB:-preserved} GiB, persistent_data=$(
    if [[ $HAS_DATA_PART -eq 1 ]]; then
      echo "remaining (~$(( drive_gib - boot_total - ${LIVE_NIX_SIZE_GIB:-0} )) GiB)"
    else
      echo "none"
    fi
  )"
  echo
  read -r -p "Proceed with this layout on $TARGET_DRIVE? [yes/N] " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || exit 1
}

compute_sizes() {
  local drive_gib="$1"
  local boot_total=$(( EFI_SIZE_GIB + ISOS_SIZE_GIB ))

  if (( drive_gib < 32 )); then
    LIVE_NIX_SIZE_GIB=$(( drive_gib - boot_total - 1 ))
    HAS_DATA_PART=0
  elif (( drive_gib < 512 )); then
    local remaining=$(( drive_gib - boot_total ))
    LIVE_NIX_SIZE_GIB=$(( remaining * 60 / 100 ))
    HAS_DATA_PART=1
  else
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
  EFI_PART="$(part_path 1)"
  ISOS_PART="$(part_path 2)"
  LIVE_PART="$(part_path 3)"

  if [[ $HAS_DATA_PART -eq 1 ]]; then
    DATA_PART="$(part_path 4)"
  else
    DATA_PART=""
  fi
}

layout_ready() {
  discover_layout
  local efi_label live_label isos_label
  efi_label="$(lsblk -n -o LABEL "$EFI_PART" 2>/dev/null || true)"
  isos_label="$(lsblk -n -o LABEL "$ISOS_PART" 2>/dev/null || true)"
  live_label="$(lsblk -n -o LABEL "$LIVE_PART" 2>/dev/null || true)"
  [[ "$efi_label"  == "LACIE_EFI"   ]] || return 1
  [[ "$isos_label" == "lacie_isos"  ]] || return 1
  [[ "$live_label" == "live_nix"    ]] || return 1
}

prepare_tools() {
  check_required_cmds
  get_drive_facts
  discover_latest_iso
  log "Target drive: $TARGET_DRIVE"
  log "ISO URL: $ISO_URL"
  log "Repo: $REPO_URL ($REPO_BRANCH)"
  if [[ $DO_NIXOS_INSTALL -eq 1 ]]; then
    log "NixOS install: ${FLAKE_PATH}#${FLAKE_TARGET}"
  fi
}

ensure_mountpoint() {
  mkdir -p "$1"
}

mount_partitions() {
  ensure_mountpoint "$EFI_MOUNT"
  ensure_mountpoint "$ISOS_MOUNT"
  ensure_mountpoint "$LIVE_MOUNT"

  umount "$DATA_MOUNT" "$LIVE_MOUNT" "$ISOS_MOUNT" "$EFI_MOUNT" 2>/dev/null || true

  mount "$EFI_PART"  "$EFI_MOUNT"
  mount "$ISOS_PART" "$ISOS_MOUNT"
  mount "$LIVE_PART" "$LIVE_MOUNT"

  if [[ $HAS_DATA_PART -eq 1 && -n "$DATA_PART" ]]; then
    ensure_mountpoint "$DATA_MOUNT"
    mount "$DATA_PART" "$DATA_MOUNT" || log "Warning: persistent_data mount failed — continuing"
  fi

  log "Mounts:"
  mount | grep -E "${EFI_MOUNT}|${ISOS_MOUNT}|${LIVE_MOUNT}|${DATA_MOUNT}" || true
}

stage_iso() {
  local iso_path="${ISOS_MOUNT}/${ISO_NAME}"
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

  cleanup_install() {
    log "Unmounting install root..."
    umount -R "$INSTALL_ROOT" 2>/dev/null || true
  }
  trap cleanup_install EXIT

  log "Mounting live_nix at $INSTALL_ROOT"
  mountpoint -q "$INSTALL_ROOT" || mount "$LIVE_PART" "$INSTALL_ROOT"

  log "Mounting LACIE_EFI at $INSTALL_ROOT/boot"
  mountpoint -q "$INSTALL_ROOT/boot" || mount "$EFI_PART" "$INSTALL_ROOT/boot"

  log "Running nixos-install --flake ${FLAKE_PATH}#${FLAKE_TARGET} --root $INSTALL_ROOT"
  log "(this takes 10-20 min — output always shown)"
  nixos-install \
    --flake "${FLAKE_PATH}#${FLAKE_TARGET}" \
    --root "$INSTALL_ROOT" \
    --no-root-passwd \
    2>&1 | tee "${LOG_DIR}/nixos-install.log"

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
     The Kanagawa GRUB menu will appear. Secure Boot must be OFF. UEFI mode required.

  4. After first boot, rebuild to apply any pending changes:
       sudo nixos-rebuild switch --flake /nix-configs#$FLAKE_TARGET

  5. Regenerate hardware config on the target machine and commit:
       nixos-generate-config --no-filesystems --show-hardware-config > /nix-configs/hosts/$FLAKE_TARGET/hardware-configuration.nix
       git -C /nix-configs commit -am "feat(lacie): update hardware-configuration.nix"

EOF
}

stage_win11_iso() {
  if [[ -z "$WIN11_ISO" ]]; then
    log "[win11] no --win11-iso provided; skipping"
    return 0
  fi

  [[ -f "$WIN11_ISO" ]] || die "Win11 ISO not found: $WIN11_ISO"

  local dest="${ISOS_MOUNT}/$(basename "$WIN11_ISO")"

  if [[ -f "$dest" ]]; then
    log "[win11] already staged: $dest"
    return 0
  fi

  # Note: GRUB loopback booting of Windows ISOs is not supported — the ISO is
  # staged here for manual dd/Rufus use on another machine.
  log "[win11] staging $(basename "$WIN11_ISO") to lacie_isos partition..."
  rsync --progress "$WIN11_ISO" "$dest"
  sync
  log "[win11] done (use Rufus or dd on another machine to boot Windows from this ISO)"
}

validate_workspace() {
  log "Workspace validation:"
  test -d "${LIVE_MOUNT}/nix-configs" || die "Missing nix-configs directory on live_nix."
  test -d "${LIVE_MOUNT}/recovery" || die "Missing recovery directory on live_nix."
  test -f "${ISOS_MOUNT}/${ISO_NAME}" || die "Missing staged ISO on lacie_isos partition."
  if [[ -d "${LIVE_MOUNT}/nix-configs/.git" ]]; then
    git -C "${LIVE_MOUNT}/nix-configs" rev-parse --abbrev-ref HEAD
    git -C "${LIVE_MOUNT}/nix-configs" status --short
  fi
}

summarize_next_steps() {
  log "USB disk is ready."
  echo "  EFI:       $EFI_MOUNT"
  echo "  ISOs:      $ISOS_MOUNT"
  echo "  live_nix:  $LIVE_MOUNT"
  if [[ $HAS_DATA_PART -eq 1 ]]; then
    echo "  data:      $DATA_MOUNT"
  fi
  echo "  repo path: ${LIVE_MOUNT}/nix-configs"
  echo "  ISO path:  ${ISOS_MOUNT}/${ISO_NAME}"
  echo
  echo "ISO naming convention for GRUB loopback entries:"
  echo "  home-office-installer.iso   — NixOS custom installer"
  echo "  nixos-latest-graphical.iso  — Official NixOS live"
  echo "  kali-live-latest.iso        — Kali Linux live"
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
    --isos-size)
      ISOS_SIZE_GIB="${2:-}"
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
    run_phase partition_disk partition_disk
    run_phase format_efi_isos format_efi_isos
    run_phase install_grub install_grub
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
