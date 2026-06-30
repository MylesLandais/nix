#!/usr/bin/env bash
# SPICE display helpers for local QEMU runners (Linux mgmt consoles).
# Injected by flake app before test-windows-qemu.sh (uses global log/die/args).

qemu_spice_default_port() {
  case "${1:-}" in
    windows) echo "${WIN_SPICE_PORT:-5935}" ;;
    cysvuln) echo "${CYSVULN_SPICE_PORT:-5930}" ;;
    ews) echo "${EWS_SPICE_PORT:-5931}" ;;
    asrep) echo "${ASREP_SPICE_PORT:-5932}" ;;
    kali) echo "${KALI_SPICE_PORT:-5940}" ;;
    *) echo "${QEMU_SPICE_PORT:-5939}" ;;
  esac
}

qemu_spice_uri() {
  echo "spice://127.0.0.1:${1}"
}

# Appends to global shell array: args
qemu_spice_append_display_args() {
  local port=$1
  args+=(-device "virtio-vga,max_outputs=1")
  args+=(-spice "port=${port},disable-ticketing=on,addr=127.0.0.1,image-compression=off")
  args+=(-device virtio-serial-pci)
  args+=(-chardev "spicevmc,id=vdagent,debug=0,name=vdagent")
  args+=(-device "virtserialport,chardev=vdagent,name=com.redhat.spice.0")
  args+=(-display none)
}

qemu_wait_port() {
  local host="$1" port="$2" tries="${3:-120}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if command -v nc >/dev/null 2>&1; then
      nc -z -w1 "$host" "$port" 2>/dev/null && return 0
    else
      # bash /dev/tcp when nc unavailable
      (echo >/dev/tcp/"$host"/"$port") 2>/dev/null && return 0
    fi
    sleep 0.25
  done
  return 1
}

qemu_launch_spice_viewer() {
  local title="$1" port="$2"
  local uri viewer=""
  uri="$(qemu_spice_uri "$port")"
  if command -v remote-viewer >/dev/null 2>&1; then
    viewer=remote-viewer
  elif command -v virt-viewer >/dev/null 2>&1; then
    viewer=virt-viewer
  else
    die "remote-viewer not found on PATH — use: nix run .#test-windows-qemu (bundles virt-viewer)"
  fi
  log "[win-qemu] waiting for SPICE ${uri} ..."
  qemu_wait_port 127.0.0.1 "$port" || die "SPICE port ${port} never opened — is QEMU running?"
  log "[win-qemu] opening SPICE ${uri} (${title})"
  if [[ "$viewer" == remote-viewer ]]; then
    remote-viewer --title "${title}" "${uri}" &
  else
    virt-viewer --title "${title}" --connect "${uri}" &
  fi
}

qemu_launch_spice_viewer_async() {
  local title="$1" port="$2"
  (
    qemu_launch_spice_viewer "$title" "$port"
  ) &
}

qemu_launch_vnc_viewer_async() {
  local display="$1"
  local port=$((5900 + ${display#:}))
  (
    log "[win-qemu] waiting for VNC 127.0.0.1:${port} ..."
    qemu_wait_port 127.0.0.1 "$port" || die "VNC port ${port} never opened"
    if command -v remote-viewer >/dev/null 2>&1; then
      log "[win-qemu] opening VNC 127.0.0.1:${port}"
      remote-viewer "vnc://127.0.0.1:${port}" &
    elif command -v vncviewer >/dev/null 2>&1; then
      vncviewer "127.0.0.1:${port}" &
    else
      die "no VNC viewer found — use: nix run .#test-windows-qemu"
    fi
  ) &
}
