set -euo pipefail
root="${XDG_STATE_HOME:-$HOME/.local/state}/waydroid-script"
mkdir -p "$(dirname "$root")"
if [ ! -d "$root/.git" ]; then
  git clone --depth 1 https://github.com/casualsnek/waydroid_script.git "$root"
else
  git -C "$root" pull --ff-only
fi
cpu_vendor=$(grep -m1 vendor_id /proc/cpuinfo || true)
case "$cpu_vendor" in
  *AuthenticAMD*) echo "AMD detected: choose Android 13 -> Install -> libndk only." ;;
  *GenuineIntel*) echo "Intel detected: choose Android 13 -> Install -> libhoudini only." ;;
  *) echo "Unknown CPU vendor; inspect before selecting a translation layer." ;;
esac
echo "Do not install Magisk, root helpers, or spoofing modules."
cd "$root"
exec sudo env PYTHONPATH="$root" @NIX1@/bin/python3 main.py
