#!/usr/bin/env bash
# Tiered QEMU boot tests for the lacie GRUB loopback / findiso path.
#
#   Tier 1 — initrd findiso only (fastest):
#     sudo ./scripts/test-usb-qemu.sh --iso-only --serial --auto-device
#     sudo ./scripts/test-usb-qemu.sh --iso-only --serial \
#       --kernel /tmp/k/bzImage --initrd /tmp/k/initrd --isos-part /dev/sda2
#
#   Tier 2 — GRUB loopback (daily driver):
#     sudo ./scripts/test-usb-qemu.sh --partitions --serial --auto-device
#
#   Tier 3 — full USB passthrough (realistic):
#     sudo ./scripts/test-usb-qemu.sh --device /dev/sda --serial
#
#   Tier 4 — SSH ingress smoke (pre-flash gate):
#     sudo ./scripts/test-usb-qemu.sh --ssh-smoke --auto-device
#
# Options:
#   --partitions            Attach p1 (EFI) + p2 (isos) as virtio (Tier 2, default)
#   --iso-only              Direct kernel boot with findiso= (Tier 1)
#   --device /dev/sdX       Whole disk via usb-storage (Tier 3)
#   --ssh-smoke             Boot full ISO via findiso + SLIRP user-net, ssh
#                           from cerberus to 127.0.0.1:2222, verify hostname
#                           and /etc/iso-build-info (Tier 4)
#   --auto-device           Resolve LACIE_EFI + lacie_isos on the lacie drive
#   --efi-part /dev/sdXN    EFI partition override
#   --isos-part /dev/sdXN   ISOs partition override
#   --iso PATH              ISO file (Tier 1: extract kernel/initrd when --kernel unset)
#   --kernel PATH           Tier 1: inject bzImage from toplevel build
#   --initrd PATH           Tier 1: inject initrd from toplevel build
#   --findiso PATH          findiso= kernel arg (default: /home-office-installer.iso)
#   --ssh-key PATH          Identity used by Tier 4 (default: ~/.ssh/id_ed25519)
#   --ssh-user USER         SSH user for Tier 4 (default: warby)
#   --ssh-port PORT         Host port forwarded to guest 22 (default: 2222)
#   --ssh-timeout SEC       Max seconds to wait for sshd (default: 240)
#   --serial                Headless serial console (-nographic). Exit: Ctrl+A X
#   --log-file PATH         Tee serial output to file
#   --expect REGEX          Exit 0 when REGEX appears in log (implies --serial)
#   --timeout SEC           Max seconds when --expect is set (default: 300)
#   --dry-run               Resolve devices and print QEMU plan; do not launch
#   --mem 4G                Guest RAM
#   --smp 2                 Guest CPUs
#
# snapshot=on — QEMU writes go to a tmp overlay; real device is not modified.
# Partitions must be unmounted before running.

set -eu

MODE="partitions"
DEVICE=""
EFI_PART=""
ISOS_PART=""
ISO=""
KERNEL=""
INITRD=""
FINDISO="/home-office-installer.iso"
AUTO_DEVICE=0
SERIAL=0
LOG_FILE=""
EXPECT=""
TIMEOUT=300
DRY_RUN=0
MEM="4G"
SMP=2

SSH_KEY="${HOME:-/home/warby}/.ssh/id_ed25519"
SSH_USER="warby"
SSH_PORT=2222
SSH_TIMEOUT=240
SSH_AGENT_SOCK="${SSH_AGENT_SOCK:-${HOME:-/home/warby}/.bitwarden-ssh-agent.sock}"

OVMF_CODE="${OVMF_CODE:-}"
OVMF_VARS_SRC="${OVMF_VARS_SRC:-}"
QEMU_BIN="${QEMU_BIN:-}"

log() { echo "[qemu-test] $*" >&2; }
die() { echo "[qemu-test] ERROR: $*" >&2; exit 1; }

usage() { sed -n '2,36p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --partitions)  MODE="partitions"; shift ;;
    --iso-only)    MODE="iso"; shift ;;
    --device)      MODE="full"; DEVICE="$2"; shift 2 ;;
    --ssh-smoke)   MODE="ssh"; SERIAL=1; shift ;;
    --ssh-key)     SSH_KEY="$2"; shift 2 ;;
    --ssh-user)    SSH_USER="$2"; shift 2 ;;
    --ssh-port)    SSH_PORT="$2"; shift 2 ;;
    --ssh-timeout) SSH_TIMEOUT="$2"; shift 2 ;;
    --ssh-agent)   SSH_AGENT_SOCK="$2"; shift 2 ;;
    --auto-device) AUTO_DEVICE=1; shift ;;
    --efi-part)    EFI_PART="$2"; shift 2 ;;
    --isos-part)   ISOS_PART="$2"; shift 2 ;;
    --iso)         ISO="$2"; shift 2 ;;
    --kernel)      KERNEL="$2"; shift 2 ;;
    --initrd)      INITRD="$2"; shift 2 ;;
    --findiso)     FINDISO="$2"; shift 2 ;;
    --serial)      SERIAL=1; shift ;;
    --log-file)    LOG_FILE="$2"; shift 2 ;;
    --expect)      EXPECT="$2"; SERIAL=1; shift 2 ;;
    --timeout)     TIMEOUT="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --mem)         MEM="$2"; shift 2 ;;
    --smp)         SMP="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *) die "Unknown arg: $1" ;;
  esac
done

if [[ $DRY_RUN -eq 0 && $EUID -ne 0 ]]; then
  # Tier 4 (ssh-smoke) only needs read access to the ISOs partition + /dev/kvm;
  # any user in the `disk` and `kvm` groups can satisfy that without sudo.
  # Running as a real user also keeps SSH_AGENT_SOCK pointing at the user's
  # Bitwarden agent (root can't reach the agent socket).
  if [[ "$MODE" == "ssh" ]] && id -nG | tr ' ' '\n' | grep -qx disk && id -nG | tr ' ' '\n' | grep -qx kvm; then
    :
  else
    die "Run with sudo (need raw block device access)"
  fi
fi

check_unmounted() {
  local dev="$1"
  if findmnt -S "$dev" >/dev/null 2>&1; then
    lsblk "$dev" >&2
    die "$dev is mounted — unmount first"
  fi
  local mounts
  mounts=$(lsblk -no MOUNTPOINT "$dev" 2>/dev/null | grep -v '^[[:space:]]*$' || true)
  [[ -z "$mounts" ]] || die "a partition of $dev is mounted at: $mounts"
}

resolve_auto_device() {
  local efi isos disk

  efi=$(blkid -L LACIE_EFI 2>/dev/null || true)
  isos=$(blkid -L lacie_isos 2>/dev/null || true)
  [[ -n "$efi" && -n "$isos" ]] || die "Could not find LACIE_EFI + lacie_isos labels"

  EFI_PART="$efi"
  ISOS_PART="$isos"

  disk=$(lsblk -no PKNAME "$efi" 2>/dev/null | head -1)
  [[ -n "$disk" ]] && DEVICE="/dev/$disk"

  log "auto: EFI=$EFI_PART ISOS=$ISOS_PART DISK=${DEVICE:-unknown}"
}

resolve_ovmf() {
  if [[ -n "$OVMF_CODE" && -n "$OVMF_VARS_SRC" && -f "$OVMF_CODE" && -f "$OVMF_VARS_SRC" ]]; then
    return 0
  fi
  local ovmf_pkg attr
  for attr in OVMF.fd OVMFFull OVMF; do
    ovmf_pkg=$(nix-build '<nixpkgs>' -A "$attr" --no-out-link 2>/dev/null) || continue
    if [[ -f "$ovmf_pkg/FV/OVMF_CODE.fd" && -f "$ovmf_pkg/FV/OVMF_VARS.fd" ]]; then
      OVMF_CODE="$ovmf_pkg/FV/OVMF_CODE.fd"
      OVMF_VARS_SRC="$ovmf_pkg/FV/OVMF_VARS.fd"
      log "OVMF: $OVMF_CODE"
      return 0
    fi
  done
  die "OVMF firmware not found (need OVMF.fd with CODE + VARS). Try: nix-shell -p OVMF.fd"
}

prepare_ovmf() {
  resolve_ovmf
  VARS_TMP=$(mktemp --suffix=-ovmf-vars.fd)
  cp "$OVMF_VARS_SRC" "$VARS_TMP"
}

resolve_qemu() {
  if [[ -n "$QEMU_BIN" && -x "$QEMU_BIN" ]]; then
    log "QEMU: $QEMU_BIN"
    return 0
  fi
  if command -v qemu-system-x86_64 >/dev/null 2>&1; then
    QEMU_BIN=$(command -v qemu-system-x86_64)
    log "QEMU: $QEMU_BIN"
    return 0
  fi
  local pkg
  pkg=$(nix-build '<nixpkgs>' -A qemu --no-out-link 2>/dev/null) \
    || die "qemu not found. Install qemu or set QEMU_BIN"
  QEMU_BIN="$pkg/bin/qemu-system-x86_64"
  log "QEMU: $QEMU_BIN"
}

print_checkpoints() {
  log "Boot checkpoints:"
  case "$MODE" in
    full|partitions)
      log "  1. OVMF firmware / boot manager"
      log "  2. GRUB menu with ISO entry (Kanagawa theme)"
      log "  3. Kernel: findiso= in serial output"
      log "  4. Initrd: Stage 1 / squashfs mount"
      log "  5. Userspace: systemd / SDDM"
      ;;
    iso)
      log "  1. Kernel: findiso= in serial output"
      log "  2. Initrd: Stage 1 / squashfs mount"
      log "  3. Userspace: systemd / SDDM"
      ;;
    ssh)
      log "  1. Tier 1 boot + SLIRP user-net (hostfwd 127.0.0.1:$SSH_PORT -> guest 22)"
      log "  2. sshd reachable on 127.0.0.1:$SSH_PORT"
      log "  3. ssh as $SSH_USER returns hostname=home-office-installer"
      log "  4. /etc/iso-build-info captured to QA log"
      ;;
  esac
}

warn_stale_iso() {
  local isos_mnt iso_path nix_file nix_mtime iso_mtime
  [[ -n "$ISOS_PART" && -b "$ISOS_PART" ]] || return 0

  nix_file="${BASH_SOURCE[0]%/*}/../modules/hosts/installer-iso/default.nix"
  [[ -f "$nix_file" ]] || return 0

  isos_mnt=$(mktemp -d)
  if mount -o ro "$ISOS_PART" "$isos_mnt" 2>/dev/null; then
    iso_path="$isos_mnt$(basename "$FINDISO")"
    # FINDISO is like /home-office-installer.iso
    iso_path="$isos_mnt/${FINDISO#/}"
    if [[ -f "$iso_path" ]]; then
      nix_mtime=$(stat -c %Y "$nix_file")
      iso_mtime=$(stat -c %Y "$iso_path")
      if (( iso_mtime < nix_mtime )); then
        log "WARNING: staged ISO on $ISOS_PART is older than installer-iso/default.nix"
        log "         Use --kernel/--initrd from a fresh toplevel build, or rebuild the ISO."
      fi
    else
      log "WARNING: $FINDISO not found on $ISOS_PART"
    fi
    umount "$isos_mnt" 2>/dev/null || true
  fi
  rmdir "$isos_mnt" 2>/dev/null || true
}

print_rebuild_hint() {
  if [[ -n "$KERNEL" && -n "$INITRD" ]]; then
    log "Rebuild hint: using injected kernel/initrd — no full ISO rebuild needed for this run"
  elif [[ "$MODE" == "iso" ]]; then
    log "Rebuild hint: boot-path iteration → nix build toplevel + extract-installer-boot.sh"
  elif [[ "$MODE" == "partitions" ]]; then
    log "Rebuild hint: GRUB changes → setup-nix-usb.sh --grub-only (no ISO rebuild)"
  fi
}

# --- resolve devices ---

if [[ $AUTO_DEVICE -eq 1 ]]; then
  resolve_auto_device
fi

case "$MODE" in
  full)
    [[ -n "$DEVICE" && -b "$DEVICE" ]] || die "Tier 3 requires --device /dev/sdX"
    check_unmounted "$DEVICE"
    ;;
  partitions)
    [[ -n "$DEVICE" && -b "$DEVICE" ]] || die "Tier 2 requires --device or --auto-device (whole disk)"
    check_unmounted "$DEVICE"
    ;;
  iso)
    [[ -n "$ISOS_PART" && -b "$ISOS_PART" ]] || die "Tier 1 requires --isos-part or --auto-device"
    check_unmounted "$ISOS_PART"
    ;;
  ssh)
    [[ -n "$ISOS_PART" && -b "$ISOS_PART" ]] || die "Tier 4 requires --isos-part or --auto-device"
    check_unmounted "$ISOS_PART"
    [[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY (pass --ssh-key)"
    ;;
esac

print_rebuild_hint
warn_stale_iso
print_checkpoints

if [[ $DRY_RUN -eq 1 ]]; then
  log "dry-run: would launch QEMU (mode=$MODE serial=$SERIAL expect=${EXPECT:-none})"
  exit 0
fi

KTMP=""
ITMP=""
LOOP_DEV=""
DATA_DEV=""
ISO_MNT=""
QEMU_PID=""
VARS_TMP=""

cleanup() {
  [[ -n "$QEMU_PID" ]] && kill "$QEMU_PID" 2>/dev/null || true
  if [[ -n "$DATA_DEV" ]]; then
    umount "$DATA_DEV" 2>/dev/null || udisksctl unmount -b "$DATA_DEV" 2>/dev/null || true
  fi
  if [[ -n "$ISO_MNT" && -d "$ISO_MNT" ]]; then
    umount "$ISO_MNT" 2>/dev/null || true
    rmdir "$ISO_MNT" 2>/dev/null || true
  fi
  if [[ -n "$LOOP_DEV" ]]; then
    udisksctl loop-delete -b "$LOOP_DEV" 2>/dev/null || true
  fi
  rm -f "$VARS_TMP"
  [[ -n "$KTMP" && "$KTMP" == /tmp/* ]] && rm -f "$KTMP"
  [[ -n "$ITMP" && "$ITMP" == /tmp/* ]] && rm -f "$ITMP"
}
trap cleanup EXIT

run_qemu() {
  resolve_qemu
  local -a qemu_args display_args

  qemu_args=(
    "$QEMU_BIN"
    -enable-kvm
    -m "$MEM"
    -cpu host
    -smp "$SMP"
    "$@"
  )

  if [[ $SERIAL -eq 1 ]]; then
    display_args=(-nographic -serial mon:stdio)
  else
    display_args=(-display gtk -serial stdio)
  fi

  if [[ -n "$EXPECT" ]]; then
    run_qemu_expect "${qemu_args[@]}" "${display_args[@]}"
    return $?
  fi

  if [[ -n "$LOG_FILE" && $SERIAL -eq 1 ]]; then
    log "logging serial output to $LOG_FILE"
    "${qemu_args[@]}" "${display_args[@]}" 2>&1 | tee "$LOG_FILE"
    return "${PIPESTATUS[0]}"
  fi

  exec "${qemu_args[@]}" "${display_args[@]}"
}

run_qemu_expect() {
  local -a cmd=("$@")
  local log_tmp elapsed=0

  log_tmp="${LOG_FILE:-$(mktemp --suffix=-qemu.log)}"
  [[ -n "$LOG_FILE" ]] || log "expect log: $log_tmp"

  log "waiting up to ${TIMEOUT}s for /$EXPECT/ in serial log..."
  stdbuf -oL -eL "${cmd[@]}" 2>&1 | stdbuf -oL tee "$log_tmp" &
  sleep 0.5
  QEMU_PID=$(pgrep -f 'qemu-system-x86_64.*lacie-' | head -1)
  [[ -n "$QEMU_PID" ]] || die "could not find qemu PID"

  while (( elapsed < TIMEOUT )); do
    if grep -qE "$EXPECT" "$log_tmp" 2>/dev/null; then
      log "PASS: matched /$EXPECT/"
      pkill -f 'qemu-system-x86_64.*lacie-' 2>/dev/null || true
      pkill -P $$ tee 2>/dev/null || true
      wait 2>/dev/null || true
      QEMU_PID=""
      return 0
    fi
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      wait "$QEMU_PID" 2>/dev/null || true
      QEMU_PID=""
      if grep -qE "$EXPECT" "$log_tmp" 2>/dev/null; then
        log "PASS: matched /$EXPECT/"
        return 0
      fi
      log "FAIL: QEMU exited without matching /$EXPECT/"
      return 1
    fi
    sleep 2
    elapsed=$(( elapsed + 2 ))
  done

  kill "$QEMU_PID" 2>/dev/null || true
  wait "$QEMU_PID" 2>/dev/null || true
  QEMU_PID=""
  log "FAIL: timeout after ${TIMEOUT}s without /$EXPECT/"
  return 1
}

ISO_INIT=""

extract_boot_from_iso() {
  local iso_file="$1"
  [[ -f "$iso_file" ]] || die "ISO not found: $iso_file"

  ISO_MNT=$(mktemp -d)
  if mount -o loop,ro "$iso_file" "$ISO_MNT" 2>/dev/null; then
    :
  else
    LOOP_DEV=$(losetup -f --show -r "$iso_file")
    sleep 1
    DATA_DEV="${LOOP_DEV}p1"
    [[ -b "$DATA_DEV" ]] || DATA_DEV="$LOOP_DEV"
    mount -o ro "$DATA_DEV" "$ISO_MNT" || die "could not mount ISO: $iso_file"
  fi

  local kernel_src initrd_src grub_cfg
  kernel_src=$(find "$ISO_MNT/boot" -name 'bzImage' -print -quit 2>/dev/null)
  initrd_src=$(find "$ISO_MNT/boot" -name 'initrd' -print -quit 2>/dev/null)
  [[ -n "$kernel_src" && -n "$initrd_src" ]] || die "no kernel/initrd in ISO"

  # Tier 4 needs init=/nix/store/...nixos-system-.../init from the ISO's GRUB
  # cmdline, otherwise stage 1 cannot locate stage 2 after findiso overlay.
  for grub_cfg in \
      "$ISO_MNT/EFI/BOOT/grub.cfg" \
      "$ISO_MNT/boot/grub/grub.cfg" \
      "$ISO_MNT/boot/grub/loopback.cfg"; do
    [[ -f "$grub_cfg" ]] || continue
    ISO_INIT=$(grep -oE 'init=/nix/store/[^ ]+' "$grub_cfg" | head -1 || true)
    [[ -n "$ISO_INIT" ]] && break
  done

  KTMP=$(mktemp --suffix=-bzImage)
  ITMP=$(mktemp --suffix=-initrd)
  cp "$kernel_src" "$KTMP"
  cp "$initrd_src" "$ITMP"
  log "extracted kernel: $KTMP"
  log "extracted initrd: $ITMP"
  [[ -n "$ISO_INIT" ]] && log "extracted init param: $ISO_INIT"
}


# --- Tier 3: full USB ---

if [[ "$MODE" == "full" ]]; then
  prepare_ovmf
  log "mode: Tier 3 — full USB passthrough"
  log "device: $DEVICE (snapshot=on)"

  args=(
    -machine "q35,smm=on"
    -global "driver=cfi.pflash01,property=secure,value=off"
    -global ICH9-LPC.disable_s3=1
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$VARS_TMP"
    -drive "file=$DEVICE,format=raw,snapshot=on,if=none,id=usb0"
    -device "qemu-xhci,id=xhci"
    -device "usb-storage,bus=xhci.0,drive=usb0"
    -boot menu=on
    -name lacie-usb-test
  )

  run_qemu "${args[@]}"
  exit $?

fi

# --- Tier 2: partitions ---

if [[ "$MODE" == "partitions" ]]; then
  prepare_ovmf
  [[ -n "$DEVICE" && -b "$DEVICE" ]] || die "Tier 2 requires whole disk (--auto-device or --device)"
  check_unmounted "$DEVICE"
  log "mode: Tier 2 — GRUB loopback (virtio whole disk)"
  log "disk:   $DEVICE (snapshot=on, bootindex=1)"

  args=(
    -machine "q35,smm=on"
    -global "driver=cfi.pflash01,property=secure,value=off"
    -global ICH9-LPC.disable_s3=1
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$VARS_TMP"
    -drive "file=$DEVICE,format=raw,snapshot=on,if=none,id=disk0"
    -device "virtio-blk-pci,drive=disk0,bootindex=1"
    -name lacie-partitions-test
  )

  run_qemu "${args[@]}"
  exit $?
fi

resolve_boot_artifacts() {
  if [[ -n "$KERNEL" && -n "$INITRD" ]]; then
    KTMP="$KERNEL"
    ITMP="$INITRD"
    log "kernel: $KTMP"
    log "initrd: $ITMP"
  elif [[ -n "$ISO" ]]; then
    extract_boot_from_iso "$ISO"
  elif [[ -n "$ISOS_PART" ]]; then
    ISO_MNT=$(mktemp -d)
    mount -o ro "$ISOS_PART" "$ISO_MNT"
    iso_on_part="$ISO_MNT/${FINDISO#/}"
    [[ -f "$iso_on_part" ]] || die "No ISO at $iso_on_part — pass --iso or --kernel/--initrd"
    extract_boot_from_iso "$iso_on_part"
    umount "$ISO_MNT"
    ISO_MNT=""
    rmdir "$ISO_MNT" 2>/dev/null || true
  else
    die "requires --kernel/--initrd, --iso, or ISO file on --isos-part"
  fi
}

# --- Tier 4: SSH smoke ---

if [[ "$MODE" == "ssh" ]]; then
  log "mode: Tier 4 — SSH ingress smoke"
  log "ISOS: $ISOS_PART (snapshot=on)"
  log "findiso: $FINDISO"
  log "ssh key: $SSH_KEY"
  log "user@127.0.0.1:$SSH_PORT, timeout ${SSH_TIMEOUT}s"

  resolve_boot_artifacts

  # If we extracted the ISO's GRUB cmdline, use its init= so stage 2 init can
  # be located in the squashfs overlay. Mirror the other args the ISO's GRUB
  # menu normally passes (root=LABEL=HOMEOFFICE, nohibernate, lsm=...).
  cmdline="console=ttyS0 loglevel=4 boot.shell_on_fail findiso=$FINDISO root=LABEL=HOMEOFFICE nohibernate lsm=landlock,yama,bpf"
  [[ -n "$ISO_INIT" ]] && cmdline="$cmdline $ISO_INIT"

  LOG_FILE="${LOG_FILE:-$(mktemp --suffix=-tier4-qemu.log)}"
  : > "$LOG_FILE"
  chmod 644 "$LOG_FILE" 2>/dev/null || true
  log "QEMU log: $LOG_FILE"
  log "cmdline:  $cmdline"

  args=(
    -machine q35
    -m "$MEM"
    -cpu host
    -smp "$SMP"
    -enable-kvm
    -drive "file=$ISOS_PART,format=raw,snapshot=on,if=none,id=isos0"
    -device "virtio-blk-pci,drive=isos0"
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22"
    -device "virtio-net-pci,netdev=net0"
    -kernel "$KTMP"
    -initrd "$ITMP"
    -append "$cmdline"
    -nographic
    -serial "file:$LOG_FILE"
    -name lacie-ssh-smoke
  )

  resolve_qemu
  log "launching QEMU in background ..."
  "$QEMU_BIN" "${args[@]}" &
  QEMU_PID=$!
  log "QEMU pid: $QEMU_PID"

  ssh_ok=0
  elapsed=0
  while (( elapsed < SSH_TIMEOUT )); do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      log "FAIL: QEMU exited before ssh became reachable"
      log "--- last 60 lines of $LOG_FILE ---"
      tail -n 60 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
      exit 1
    fi

    if (exec 3<>"/dev/tcp/127.0.0.1/$SSH_PORT") 2>/dev/null; then
      exec 3>&- 3<&-
      log "port $SSH_PORT open after ${elapsed}s — attempting ssh ..."

      # If the configured SSH key is a passphrase-protected file (typical for
      # interactive identities) prefer the agent socket — Bitwarden's desktop
      # agent holds the decrypted automation key while the vault is open.
      # When neither key file works in batch mode, the agent path is the only
      # one that succeeds for unattended automation.
      ssh_args=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o ConnectTimeout=10
        -o BatchMode=yes
        -p "$SSH_PORT"
      )
      if [[ -n "$SSH_AGENT_SOCK" && -S "$SSH_AGENT_SOCK" ]]; then
        ssh_args+=( -o "IdentityAgent=$SSH_AGENT_SOCK" )
      else
        ssh_args+=(
          -i "$SSH_KEY"
          -o IdentitiesOnly=yes
          -o IdentityAgent=none
        )
      fi

      ssh_out=$(ssh \
        "${ssh_args[@]}" \
        "${SSH_USER}@127.0.0.1" \
        'hostname; echo "--- /etc/iso-build-info ---"; cat /etc/iso-build-info 2>/dev/null || echo "(no /etc/iso-build-info)"' \
        2>&1) && rc=0 || rc=$?

      if [[ $rc -eq 0 ]]; then
        printf '%s\n' "$ssh_out" | sed 's/^/  /' >&2
        guest_host=$(printf '%s\n' "$ssh_out" | head -1)
        if [[ "$guest_host" == "home-office-installer" ]]; then
          log "PASS: ssh+hostname == home-office-installer"
          ssh_ok=1
        else
          log "FAIL: ssh worked but hostname=$guest_host (expected home-office-installer)"
        fi
        break
      else
        if (( elapsed % 30 == 0 )) || [[ "$ssh_out" == *"Permission denied"* ]]; then
          log "ssh attempt rc=$rc: ${ssh_out//$'\n'/ | }"
        fi
        # Permission denied means sshd is up — no point in retrying, the key
        # is the problem and waiting longer will not fix it.
        if [[ "$ssh_out" == *"Permission denied"* ]]; then
          log "FAIL: sshd up but key rejected — ISO does not trust this identity"
          break
        fi
      fi
    fi

    sleep 5
    elapsed=$(( elapsed + 5 ))
  done

  log "shutting down QEMU (pid $QEMU_PID)"
  kill "$QEMU_PID" 2>/dev/null || true
  wait "$QEMU_PID" 2>/dev/null || true
  QEMU_PID=""

  if [[ $ssh_ok -ne 1 ]]; then
    log "FAIL: SSH smoke timed out after ${SSH_TIMEOUT}s"
    log "--- last 60 lines of $LOG_FILE ---"
    tail -n 60 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    exit 1
  fi
  exit 0
fi

# --- Tier 1: iso-only ---

log "mode: Tier 1 — initrd findiso"
log "ISOS: $ISOS_PART (snapshot=on)"
log "findiso: $FINDISO"

resolve_boot_artifacts

[[ $SERIAL -eq 1 ]] || die "Tier 1 requires --serial (or --expect) for findiso testing"

args=(
  -machine q35
  -drive "file=$ISOS_PART,format=raw,snapshot=on,if=none,id=isos0"
  -device "virtio-blk-pci,drive=isos0"
  -kernel "$KTMP"
  -initrd "$ITMP"
  -append "console=ttyS0 loglevel=7 boot.shell_on_fail findiso=$FINDISO root=fstab"
  -name lacie-iso-test
)

if [[ -n "$EXPECT" ]]; then
  run_qemu "${args[@]}"
else
  run_qemu "${args[@]}"
fi
