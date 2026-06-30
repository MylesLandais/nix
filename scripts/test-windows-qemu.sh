#!/usr/bin/env bash
# Validate Windows install media in QEMU under Secure Boot + TPM 2.0 BEFORE
# touching hardware. Mirrors the OVMF/QEMU helpers in test-usb-qemu.sh but boots
# a Windows ISO (El-Torito) against a scratch qcow2, with anti-cheat-relevant
# firmware features turned ON (Secure Boot enabled, swtpm TPM 2.0 attached).
#
# Scopes:
#   Media check (no install)  — confirm the ISO/USB reaches Windows Setup:
#     ./scripts/test-windows-qemu.sh --iso ~/win-kit-staging/Windows.iso --check-media
#
#   Full unattended dry-run   — autounattend on a virtual floppy + install disk:
#     ./scripts/test-windows-qemu.sh --iso ~/win-kit-staging/Windows.iso --fresh
#
#   Boot golden + SPICE viewer:
#     ./scripts/test-windows-qemu.sh --boot-target --target ~/win-kit-staging/golden/win11-pro-gamer-*.qcow2 \
#       --open-spice --user-net --ovmf-vars-persist ~/win-kit-staging/golden/ovmf-vars.fd \
#       --tpm-dir ~/win-kit-staging/golden/swtpm
#
# Options:
#   --iso PATH              Windows install ISO
#   --device /dev/sdX       Boot a built USB via usb-storage (snapshot=on)
#   --target PATH           Scratch qcow2 install disk (default: /tmp/win-test.qcow2)
#   --disk-size SIZE        Size for a freshly created target (default: 64G)
#   --fresh                 Recreate the target qcow2 before booting
#   --check-media           No target disk; boot to Setup only
#   --boot-target           Boot an installed qcow2 only
#   --unattend PATH         autounattend.xml on virtual floppy
#   --no-unattend           Skip floppy injection
#   --payload-dir DIR       Secondary ISO (scripts + Installers/)
#   --virtio-iso PATH       Attach virtio-win.iso as extra CD
#   --spice                 SPICE display (virtio-vga; needs virtio-win in guest)
#   --open-spice            --spice + auto-launch remote-viewer
#   --spice-port PORT       SPICE port (default: 5935)
#   --vnc :N                VNC display (e.g. :1 -> localhost:5901)
#   --open-viewer           Auto-launch VNC viewer when using --vnc
#   --user-net              SLIRP NAT + RustDesk/Moonlight port forwards
#   --ovmf-vars-persist P   Reuse writable OVMF vars across boots
#   --tpm-dir PATH          Persistent swtpm state directory
#   --mem SIZE              Guest RAM (default: 8G)
#   --smp N                 vCPUs (default: 4)
#   --no-tpm / --no-secureboot
#   --ovmf-code / --ovmf-vars PATH
#   --dry-run               Print QEMU plan and exit
#
# Env: OVMF_CODE, OVMF_VARS_SRC, QEMU_BIN, SWTPM_BIN, WIN_RUSTDESK_PASSWORD, WIN_SUNSHINE_PIN

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "[win-qemu] $*" >&2; }
die() { echo "[win-qemu] ERROR: $*" >&2; exit 1; }
usage() { sed -n '2,55p' "$0"; exit 0; }

# qemu-spice helpers: injected by flake app (scripts/lib/qemu-spice.sh)

ISO=""
DEVICE=""
TARGET="/tmp/win-test.qcow2"
DISK_SIZE="64G"
FRESH=0
CHECK_MEDIA=0
BOOT_TARGET=0
UNATTEND=""
USE_UNATTEND=1
PAYLOAD_DIR=""
VIRTIO_ISO=""
MEM="8G"
SMP=4
VNC=""
USE_SPICE=0
OPEN_VIEWER=0
SPICE_PORT=""
USE_USER_NET=0
USE_TPM=1
USE_SECUREBOOT=1
DRY_RUN=0
OVMF_VARS_PERSIST=""
TPM_DIR_PERSIST=""

OVMF_CODE="${OVMF_CODE:-}"
OVMF_VARS_SRC="${OVMF_VARS_SRC:-}"
QEMU_BIN="${QEMU_BIN:-}"
SWTPM_BIN="${SWTPM_BIN:-}"

VARS_PERSIST=0
TPM_PERSIST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)                 ISO="$2"; shift 2 ;;
    --device)              DEVICE="$2"; shift 2 ;;
    --target)              TARGET="$2"; shift 2 ;;
    --disk-size)           DISK_SIZE="$2"; shift 2 ;;
    --fresh)               FRESH=1; shift ;;
    --check-media)         CHECK_MEDIA=1; shift ;;
    --boot-target)         BOOT_TARGET=1; shift ;;
    --unattend)            UNATTEND="$2"; USE_UNATTEND=1; shift 2 ;;
    --no-unattend)         USE_UNATTEND=0; shift ;;
    --payload-dir)         PAYLOAD_DIR="$2"; shift 2 ;;
    --virtio-iso)          VIRTIO_ISO="$2"; shift 2 ;;
    --spice)               USE_SPICE=1; shift ;;
    --open-spice)          USE_SPICE=1; OPEN_VIEWER=1; shift ;;
    --spice-port)          SPICE_PORT="$2"; shift 2 ;;
    --vnc)                 VNC="$2"; shift ;;
    --open-viewer)         OPEN_VIEWER=1; shift ;;
    --user-net)            USE_USER_NET=1; shift ;;
    --ovmf-vars-persist)   OVMF_VARS_PERSIST="$2"; shift 2 ;;
    --tpm-dir)             TPM_DIR_PERSIST="$2"; shift 2 ;;
    --mem)                 MEM="$2"; shift 2 ;;
    --smp)                 SMP="$2"; shift 2 ;;
    --no-tpm)              USE_TPM=0; shift ;;
    --no-secureboot)       USE_SECUREBOOT=0; shift ;;
    --ovmf-code)           OVMF_CODE="$2"; shift 2 ;;
    --ovmf-vars)           OVMF_VARS_SRC="$2"; shift 2 ;;
    --dry-run)             DRY_RUN=1; shift ;;
    -h|--help)             usage ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ -n "$SPICE_PORT" ]] || SPICE_PORT="$(qemu_spice_default_port windows)"

KIT_ROOT="${WINDOWS_KIT_DIR:-$REPO_ROOT/windows-kit}"
[[ -n "$UNATTEND" ]] || UNATTEND="$KIT_ROOT/autounattend.xml"

# --- source media -------------------------------------------------------------

if [[ $BOOT_TARGET -eq 0 && -z "$DEVICE" && -z "$ISO" ]]; then
  for c in "$HOME/win-kit-staging/"*.iso "$HOME/Downloads/Win11_"*.iso "$HOME/Downloads/"*[Ww]indows*.iso; do
    [[ -f "$c" ]] && { ISO="$c"; break; }
  done
fi
if [[ -n "$DEVICE" ]]; then
  [[ -b "$DEVICE" ]] || die "$DEVICE is not a block device"
  [[ $EUID -eq 0 ]] || die "USB passthrough (--device) needs sudo for raw block access"
elif [[ $BOOT_TARGET -eq 1 ]]; then
  [[ -f "$TARGET" ]] || die "--boot-target requires an existing install at --target"
  USE_UNATTEND=0
  log "scope: boot installed target only ($TARGET)"
else
  [[ -f "$ISO" ]] || die "--iso PATH required (no Windows ISO found in staging/Downloads)"
fi

if [[ $USE_SPICE -eq 1 ]]; then
  log "display: SPICE on 127.0.0.1:${SPICE_PORT} (virtio-vga — install virtio-win in guest first on AHCI images)"
fi

# --- resolvers ----------------------------------------------------------------

resolve_ovmf() {
  if [[ -n "$OVMF_CODE" && -n "$OVMF_VARS_SRC" && -f "$OVMF_CODE" && -f "$OVMF_VARS_SRC" ]]; then
    log "OVMF (override): $OVMF_CODE"; return 0
  fi
  local pkg fv code="" vars=""
  for attr in OVMFFull OVMF; do
    pkg=$(nix-build '<nixpkgs>' -A "$attr" --no-out-link 2>/dev/null) || continue
    fv="$pkg/FV"
    if [[ $USE_SECUREBOOT -eq 1 ]]; then
      for c in OVMF_CODE.secboot.fd OVMF_CODE.ms.fd OVMF_CODE.fd; do
        [[ -f "$fv/$c" ]] && { code="$fv/$c"; break; }
      done
      for v in OVMF_VARS.ms.fd OVMF_VARS.secboot.fd OVMF_VARS.fd; do
        [[ -f "$fv/$v" ]] && { vars="$fv/$v"; break; }
      done
    else
      [[ -f "$fv/OVMF_CODE.fd" ]] && code="$fv/OVMF_CODE.fd"
      [[ -f "$fv/OVMF_VARS.fd" ]] && vars="$fv/OVMF_VARS.fd"
    fi
    if [[ -n "$code" && -n "$vars" ]]; then
      OVMF_CODE="$code"; OVMF_VARS_SRC="$vars"
      log "OVMF: $OVMF_CODE"
      log "VARS template: $OVMF_VARS_SRC"
      return 0
    fi
  done
  die "OVMF firmware not found"
}

resolve_qemu() {
  if [[ -n "$QEMU_BIN" && -x "$QEMU_BIN" ]]; then return 0; fi
  if command -v qemu-system-x86_64 >/dev/null 2>&1; then
    QEMU_BIN=$(command -v qemu-system-x86_64); return 0
  fi
  local pkg; pkg=$(nix-build '<nixpkgs>' -A qemu_full --no-out-link 2>/dev/null) \
    || die "qemu not found"
  QEMU_BIN="$pkg/bin/qemu-system-x86_64"
}

resolve_swtpm() {
  [[ $USE_TPM -eq 1 ]] || return 0
  if [[ -n "$SWTPM_BIN" && -x "$SWTPM_BIN" ]]; then return 0; fi
  if command -v swtpm >/dev/null 2>&1; then SWTPM_BIN=$(command -v swtpm); return 0; fi
  local pkg; pkg=$(nix-build '<nixpkgs>' -A swtpm --no-out-link 2>/dev/null) \
    || die "swtpm not found"
  SWTPM_BIN="$pkg/bin/swtpm"
}

build_unattend_floppy() {
  local floppy_img="$1" answer_file="$2"
  command -v mkfs.vfat >/dev/null 2>&1 || die "mkfs.vfat not found (dosfstools)"
  command -v mcopy >/dev/null 2>&1 || die "mcopy not found (mtools)"
  dd if=/dev/zero of="$floppy_img" bs=1024 count=1440 status=none
  mkfs.vfat -n UNATTEND "$floppy_img" >/dev/null
  mcopy -i "$floppy_img" "$answer_file" ::autounattend.xml
  log "autounattend floppy: $floppy_img ($(basename "$answer_file"))"
}

copy_payload_scripts() {
  local stage="$1" src_dir="$2"
  local kit="${WINDOWS_KIT_DIR:-$REPO_ROOT/windows-kit}"
  for script in quick_fix.ps1 gamer_verify.ps1 install_rustdesk.ps1 install_sunshine.ps1 install_virtio_win.ps1; do
    if [[ -f "$src_dir/$script" ]]; then
      cp "$src_dir/$script" "$stage/"
    elif [[ -f "$kit/$script" ]]; then
      cp "$kit/$script" "$stage/"
    elif [[ "$script" == "quick_fix.ps1" ]]; then
      die "quick_fix.ps1 not found in $src_dir or windows-kit/"
    fi
  done
  if [[ -d "$src_dir/Installers" ]]; then
    cp -a "$src_dir/Installers" "$stage/"
  fi
  if [[ -f "$src_dir/virtio-win.iso" ]]; then
    cp "$src_dir/virtio-win.iso" "$stage/"
  elif [[ -f "$HOME/win-kit-staging/virtio-win.iso" ]]; then
    cp "$HOME/win-kit-staging/virtio-win.iso" "$stage/"
  fi
}

build_payload_iso() {
  local out_iso="$1" src_dir="$2"
  local stage
  stage=$(mktemp -d)
  copy_payload_scripts "$stage" "$src_dir"
  if command -v genisoimage >/dev/null 2>&1; then
    genisoimage -quiet -J -r -V WIN_PAYLOAD -o "$out_iso" "$stage"
  elif command -v xorrisofs >/dev/null 2>&1; then
    xorrisofs -quiet -J -r -V WIN_PAYLOAD -o "$out_iso" "$stage"
  elif command -v mkisofs >/dev/null 2>&1; then
    mkisofs -quiet -J -r -V WIN_PAYLOAD -o "$out_iso" "$stage"
  else
    rm -rf "$stage"
    die "need genisoimage, xorrisofs, or mkisofs"
  fi
  rm -rf "$stage"
  log "payload ISO: $out_iso (from $src_dir)"
}

append_user_net() {
  local fwd=(
    "hostfwd=tcp::21115-:21115"
    "hostfwd=tcp::21116-:21116"
    "hostfwd=tcp::21117-:21117"
    "hostfwd=tcp::21118-:21118"
    "hostfwd=tcp::21119-:21119"
    "hostfwd=udp::21116-:21116"
    "hostfwd=tcp::47984-:47984"
    "hostfwd=tcp::47989-:47989"
    "hostfwd=tcp::47990-:47990"
    "hostfwd=udp::47984-:47984"
    "hostfwd=udp::47989-:47989"
    "hostfwd=udp::47990-:47990"
  )
  local net="id=winnet"
  local f
  for f in "${fwd[@]}"; do net+=",$f"; done
  args+=(-netdev "user,$net")
  args+=(-device "e1000e,netdev=winnet")
  log "network: user-mode NAT (RustDesk 21115-21119, Moonlight 47984-47990)"
}

# --- cleanup ------------------------------------------------------------------

VARS_TMP=""
TPM_DIR=""
SWTPM_PID=""
FLOPPY_IMG=""
PAYLOAD_ISO=""
WORK_DIR=""
MONITOR_SOCK=""
CD_INDEX=0

send_cd_boot_key() {
  local sock="$1"
  for _ in $(seq 1 50); do [[ -S "$sock" ]] && break; sleep 0.2; done
  sleep 6
  for _ in 1 2 3 4 5 6; do
    if printf 'sendkey ret\n' | socat - "UNIX-CONNECT:$sock" 2>/dev/null; then
      return 0
    fi
    sleep 4
  done
}

cleanup() {
  [[ -n "$SWTPM_PID" ]] && kill "$SWTPM_PID" 2>/dev/null || true
  if [[ $VARS_PERSIST -eq 0 && -n "$VARS_TMP" ]]; then
    rm -f "$VARS_TMP"
  fi
  if [[ $TPM_PERSIST -eq 0 && -n "$TPM_DIR" && -d "$TPM_DIR" ]]; then
    rm -rf "$TPM_DIR"
  fi
  [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
  [[ -n "$MONITOR_SOCK" && -S "$MONITOR_SOCK" ]] && rm -f "$MONITOR_SOCK"
}
trap cleanup EXIT

# --- assemble -----------------------------------------------------------------

resolve_ovmf
resolve_qemu
resolve_swtpm

if [[ -n "$OVMF_VARS_PERSIST" ]]; then
  VARS_TMP="$OVMF_VARS_PERSIST"
  VARS_PERSIST=1
  mkdir -p "$(dirname "$VARS_TMP")"
  [[ -f "$VARS_TMP" ]] || cp "$OVMF_VARS_SRC" "$VARS_TMP"
  log "OVMF vars persist: $VARS_TMP"
else
  VARS_TMP=$(mktemp --suffix=-win-ovmf-vars.fd)
  cp "$OVMF_VARS_SRC" "$VARS_TMP"
fi

args=(
  -machine "q35,smm=on"
  -enable-kvm
  -cpu host
  -m "$MEM"
  -smp "$SMP"
  -global ICH9-LPC.disable_s3=1
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
  -drive "if=pflash,format=raw,file=$VARS_TMP"
  -device "ahci,id=ahci"
  -name win-qemu-test
)

if [[ $USE_SECUREBOOT -eq 1 ]]; then
  args+=( -global "driver=cfi.pflash01,property=secure,value=on" )
  log "Secure Boot: ON"
else
  args+=( -global "driver=cfi.pflash01,property=secure,value=off" )
  log "Secure Boot: OFF"
fi

next_cd_bus() {
  CD_INDEX=$((CD_INDEX + 1))
  echo "ahci.${CD_INDEX}"
}

if [[ $BOOT_TARGET -eq 1 ]]; then
  log "source: installed disk $TARGET"
  args+=(
    -drive "file=$TARGET,if=none,id=hd0,format=qcow2"
    -device "ide-hd,bus=ahci.1,drive=hd0,bootindex=1"
  )
  CD_INDEX=1
elif [[ -n "$DEVICE" ]]; then
  log "source: USB passthrough $DEVICE (snapshot=on)"
  args+=(
    -drive "file=$DEVICE,format=raw,snapshot=on,if=none,id=usb0"
    -device "qemu-xhci,id=xhci"
    -device "usb-storage,bus=xhci.0,drive=usb0,bootindex=1"
  )
else
  log "source: ISO $ISO"
  args+=(
    -drive "file=$ISO,if=none,id=cd0,media=cdrom"
    -device "ide-cd,bus=ahci.0,drive=cd0,bootindex=1"
  )
  CD_INDEX=0
fi

if [[ $USE_UNATTEND -eq 1 && $CHECK_MEDIA -eq 0 && -z "$DEVICE" && $BOOT_TARGET -eq 0 ]]; then
  [[ -f "$UNATTEND" ]] || die "autounattend not found: $UNATTEND"
  WORK_DIR=$(mktemp -d)
  FLOPPY_IMG="$WORK_DIR/autounattend.img"
  build_unattend_floppy "$FLOPPY_IMG" "$UNATTEND"
  args+=( -drive "file=$FLOPPY_IMG,format=raw,if=floppy" )
elif [[ $USE_UNATTEND -eq 0 ]]; then
  log "autounattend: skipped"
fi

if [[ -n "$PAYLOAD_DIR" ]]; then
  [[ -d "$PAYLOAD_DIR" ]] || die "--payload-dir not found: $PAYLOAD_DIR"
  WORK_DIR="${WORK_DIR:-$(mktemp -d)}"
  PAYLOAD_ISO="$WORK_DIR/payload.iso"
  build_payload_iso "$PAYLOAD_ISO" "$PAYLOAD_DIR"
  bus=$(next_cd_bus)
  args+=(
    -drive "file=$PAYLOAD_ISO,if=none,id=cd_payload,media=cdrom"
    -device "ide-cd,bus=${bus},drive=cd_payload"
  )
fi

[[ -z "$VIRTIO_ISO" && -f "$HOME/win-kit-staging/virtio-win.iso" ]] && VIRTIO_ISO="$HOME/win-kit-staging/virtio-win.iso"
if [[ -n "$VIRTIO_ISO" ]]; then
  [[ -f "$VIRTIO_ISO" ]] || die "--virtio-iso not found: $VIRTIO_ISO"
  bus=$(next_cd_bus)
  args+=(
    -drive "file=$VIRTIO_ISO,if=none,id=cd_virtio,media=cdrom"
    -device "ide-cd,bus=${bus},drive=cd_virtio"
  )
  log "virtio-win ISO: $VIRTIO_ISO"
fi

if [[ $BOOT_TARGET -eq 0 && $CHECK_MEDIA -eq 0 ]]; then
  if [[ $FRESH -eq 1 || ! -f "$TARGET" ]]; then
    log "creating scratch target $TARGET ($DISK_SIZE)"
    qemu-img create -f qcow2 "$TARGET" "$DISK_SIZE" >/dev/null
  fi
  args+=(
    -drive "file=$TARGET,if=none,id=hd0,format=qcow2"
    -device "ide-hd,bus=ahci.1,drive=hd0,bootindex=2"
  )
elif [[ $CHECK_MEDIA -eq 1 ]]; then
  log "scope: media check only (no install target)"
fi

if [[ $USE_TPM -eq 1 ]]; then
  if [[ -n "$TPM_DIR_PERSIST" ]]; then
    TPM_DIR="$TPM_DIR_PERSIST"
    TPM_PERSIST=1
    mkdir -p "$TPM_DIR"
    log "TPM persist: $TPM_DIR"
  else
    TPM_DIR=$(mktemp -d)
  fi
  "$SWTPM_BIN" socket --tpmstate dir="$TPM_DIR" \
    --ctrl type=unixio,path="$TPM_DIR/swtpm-sock" --tpm2 --daemon \
    --pid file="$TPM_DIR/swtpm.pid"
  for _ in $(seq 1 50); do [[ -S "$TPM_DIR/swtpm-sock" ]] && break; sleep 0.1; done
  [[ -S "$TPM_DIR/swtpm-sock" ]] || die "swtpm socket did not appear"
  [[ -f "$TPM_DIR/swtpm.pid" ]] && SWTPM_PID=$(cat "$TPM_DIR/swtpm.pid")
  args+=(
    -chardev "socket,id=chrtpm,path=$TPM_DIR/swtpm-sock"
    -tpmdev "emulator,id=tpm0,chardev=chrtpm"
    -device "tpm-tis,tpmdev=tpm0"
  )
  log "TPM 2.0: swtpm ($TPM_DIR)"
else
  log "TPM: DISABLED"
fi

if [[ $USE_USER_NET -eq 1 ]]; then
  append_user_net
fi

if [[ $USE_SPICE -eq 1 ]]; then
  qemu_spice_append_display_args "$SPICE_PORT"
elif [[ -n "$VNC" ]]; then
  args+=( -display "vnc=$VNC" )
  log "display: VNC $VNC (localhost:$((5900 + ${VNC#:})))"
else
  args+=( -display gtk )
  log "display: GTK window"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  log "dry-run plan:"
  [[ $USE_SPICE -eq 1 ]] && log "SPICE URI: $(qemu_spice_uri "$SPICE_PORT")"
  [[ $OPEN_VIEWER -eq 1 && $USE_SPICE -eq 1 ]] && log "viewer: remote-viewer $(qemu_spice_uri "$SPICE_PORT")"
  [[ $OPEN_VIEWER -eq 1 && -n "$VNC" ]] && log "viewer: vnc://127.0.0.1:$((5900 + ${VNC#:}))"
  printf '  %q\n' "$QEMU_BIN" "${args[@]}" >&2
  exit 0
fi

if [[ -n "$ISO" && -z "$DEVICE" && $BOOT_TARGET -eq 0 ]]; then
  MONITOR_SOCK=$(mktemp -u --suffix=-qemu-mon.sock)
  args+=( -monitor "unix:$MONITOR_SOCK,server,nowait" )
fi

log "launching QEMU ..."
[[ -n "$PAYLOAD_DIR" ]] && log "  payload CD attached — run gamer_verify.ps1 or quick_fix.ps1 from guest"
[[ $USE_USER_NET -eq 1 ]] && log "  RustDesk: host ./scripts/rustdesk-windows-qemu.sh (ports 21116-21119)"
[[ $USE_USER_NET -eq 1 ]] && log "  Moonlight: connect to 127.0.0.1:47989 after Sunshine install in guest"

if [[ -n "$MONITOR_SOCK" ]]; then
  send_cd_boot_key "$MONITOR_SOCK" &
fi

if [[ $OPEN_VIEWER -eq 1 ]]; then
  if [[ $USE_SPICE -eq 1 ]]; then
    # Viewer must start after QEMU binds SPICE (see SecretCon run-local-kali.sh).
    qemu_launch_spice_viewer_async "Win11 QEMU" "$SPICE_PORT"
  elif [[ -n "$VNC" ]]; then
    qemu_launch_vnc_viewer_async "$VNC"
  else
    log "warning: --open-viewer has no effect without --open-spice or --vnc"
  fi
fi

exec "$QEMU_BIN" "${args[@]}"
