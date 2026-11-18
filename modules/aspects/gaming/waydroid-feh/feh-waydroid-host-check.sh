failed=0
check() { if eval "$2"; then printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; failed=1; fi; }
# The expressions are intentionally passed unevaluated to check().
# shellcheck disable=SC2016
check "x86_64 host" '[ "$(uname -m)" = x86_64 ]'
# shellcheck disable=SC2016
check "Wayland session" '[ -n "${WAYLAND_DISPLAY:-}" ]'
check "NVIDIA display adapter" 'lspci | grep -Eqi "(VGA|3D).*NVIDIA"'
check "Waydroid installed" 'command -v waydroid >/dev/null'
check "binder driver available" '[ -e /dev/binderfs/binder ] || [ -e /dev/anbox-binder ] || grep -q binder /proc/filesystems'
echo "groups: $(id -Gn)"
exit "$failed"
