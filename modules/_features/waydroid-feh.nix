{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.fehWaydroid;
  androidPackage = "com.nintendo.zaba";

  fehWaydroid = pkgs.writeShellApplication {
    name = "feh-waydroid";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      waydroid
      xdg-utils
    ];
    text = ''
      set -euo pipefail
      action="''${1:-ui}"
      shift || true
      case "$action" in
        ui) waydroid show-full-ui "$@" ;;
        stop) waydroid session stop || true ;;
        status) waydroid status ;;
        store)
          waydroid session start >/dev/null 2>&1 &
          sleep 3
          waydroid app launch com.android.vending
          ;;
        install)
          xdg-open "https://play.google.com/store/apps/details?id=${androidPackage}"
          waydroid session start >/dev/null 2>&1 &
          sleep 3
          waydroid app launch com.android.vending
          ;;
        play)
          waydroid session start >/dev/null 2>&1 &
          sleep 3
          waydroid app launch ${androidPackage}
          ;;
        shell) exec waydroid shell "$@" ;;
        *) echo "usage: feh-waydroid {ui|stop|status|store|install|play|shell}" >&2; exit 2 ;;
      esac
    '';
  };

  hostCheck = pkgs.writeShellApplication {
    name = "feh-waydroid-host-check";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      pciutils
      waydroid
    ];
    text = ''
      failed=0
      check() { if eval "$2"; then printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; failed=1; fi; }
      check "x86_64 host" '[ "$(uname -m)" = x86_64 ]'
      check "Wayland session" '[ -n "''${WAYLAND_DISPLAY:-}" ]'
      check "NVIDIA display adapter" 'lspci | grep -Eqi "(VGA|3D).*NVIDIA"'
      check "Waydroid installed" 'command -v waydroid >/dev/null'
      check "binder driver available" '[ -e /dev/binderfs/binder ] || [ -e /dev/anbox-binder ] || grep -q binder /proc/filesystems'
      echo "groups: $(id -Gn)"
      exit "$failed"
    '';
  };

  bootstrap = pkgs.writeShellApplication {
    name = "feh-waydroid-bootstrap";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      waydroid
    ];
    text = ''
      if [ "$EUID" -ne 0 ]; then echo "run with sudo" >&2; exit 1; fi
      if [ -f /var/lib/waydroid/waydroid.cfg ]; then
        if grep -Eqi 'system_ota.*(gapps|google)' /var/lib/waydroid/waydroid.cfg; then
          echo "Existing GAPPS Waydroid installation retained."
          exit 0
        fi
        echo "Refusing to overwrite existing Waydroid state at /var/lib/waydroid." >&2
        echo "Inspect it manually; no data was changed." >&2
        exit 1
      fi
      waydroid init -s GAPPS -f
      waydroid prop set persist.waydroid.width ${toString cfg.width}
      waydroid prop set persist.waydroid.height ${toString cfg.height}
      waydroid prop set persist.waydroid.multi_windows true
      echo "Initialized Android GAPPS. Start with: feh-waydroid ui"
    '';
  };

  armTranslation = pkgs.writeShellApplication {
    name = "feh-waydroid-arm-translation";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      git
      pciutils
      python3
      waydroid
    ];
    text = ''
      set -euo pipefail
      root="''${XDG_STATE_HOME:-$HOME/.local/state}/waydroid-script"
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
      exec sudo env PYTHONPATH="$root" ${pkgs.python3}/bin/python3 main.py
    '';
  };

  deviceId = pkgs.writeShellApplication {
    name = "feh-waydroid-device-id";
    runtimeInputs = with pkgs; [
      coreutils
      waydroid
      xdg-utils
    ];
    text = ''
      id=$(sudo waydroid shell -- sh -c "sqlite3 /data/data/com.google.android.gsf/databases/gservices.db 'select value from main where name=\"android_id\";'" | tr -d '\r')
      if [ -z "$id" ]; then echo "No GSF ID found; start Android and finish initial setup first." >&2; exit 1; fi
      printf 'GSF ID: %s\n' "$id"
      xdg-open https://www.google.com/android/uncertified/ >/dev/null 2>&1 || true
    '';
  };

  doctor = pkgs.writeShellApplication {
    name = "feh-waydroid-doctor";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gnugrep
      systemd
      waydroid
    ];
    text = ''
      echo "== status =="; waydroid status || true
      echo "== service =="; systemctl --no-pager --full status waydroid-container.service || true
      echo "== properties =="; waydroid prop get ro.product.cpu.abilist || true; waydroid prop get ro.dalvik.vm.native.bridge || true
      echo "== FEH =="
      sudo waydroid shell -- dumpsys package ${androidPackage} 2>/dev/null | grep -E 'version(Name|Code)=|primaryCpuAbi|secondaryCpuAbi' || echo "FEH not installed"
      echo "== recent crashes =="
      sudo waydroid shell -- logcat -d -t 500 2>/dev/null | grep -Ei '${androidPackage}|FATAL EXCEPTION|native bridge|SIG(SEGV|ABRT)' | tail -n 100 || true
    '';
  };

  gameplayTest = pkgs.writeShellApplication {
    name = "feh-waydroid-test";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      waydroid
    ];
    text = ''
      seconds="''${1:-300}"
      case "$seconds" in *[!0-9]*|"") echo "duration must be seconds" >&2; exit 2;; esac
      out="''${XDG_STATE_HOME:-$HOME/.local/state}/feh-waydroid/tests/$(date -u +%Y%m%dT%H%M%SZ)"
      mkdir -p "$out"
      waydroid status >"$out/status.txt" 2>&1 || true
      sudo waydroid shell -- logcat -c || true
      waydroid session start >/dev/null 2>&1 &
      sleep 3
      waydroid app launch ${androidPackage} || true
      echo "Capture running for $seconds seconds; exercise title screen and one guest battle."
      sleep "$seconds"
      sudo waydroid shell -- screencap -p /sdcard/feh-test.png || true
      sudo waydroid shell -- cat /sdcard/feh-test.png >"$out/screenshot.png" 2>/dev/null || true
      sudo waydroid shell -- dumpsys package ${androidPackage} >"$out/package.txt" 2>&1 || true
      sudo waydroid shell -- dumpsys activity activities >"$out/activity.txt" 2>&1 || true
      sudo waydroid shell -- logcat -d >"$out/logcat.txt" 2>&1 || true
      if grep -Eqi 'FATAL EXCEPTION|SIG(SEGV|ABRT)|Process com\.nintendo\.zaba .* died' "$out/logcat.txt"; then verdict=FAIL-CRASH; else verdict=PASS-PENDING-VISUAL; fi
      printf '%s\n' "$verdict" | tee "$out/verdict.txt"
      echo "Evidence: $out"
    '';
  };

  androidDevice = pkgs.writeShellApplication {
    name = "feh-android-device";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gnugrep
      usbutils
    ];
    text = ''
      echo "== USB devices =="; lsusb
      adb start-server >/dev/null
      lines=$(adb devices -l | sed '1d;/^[[:space:]]*$/d')
      if [ -z "$lines" ]; then
        if lsusb | grep -Eqi 'Samsung|Google|Android|Motorola|OnePlus|Xiaomi'; then
          echo "Android-like USB device present, but absent from ADB (check USB mode, debugging, and cable permissions)."; exit 2
        fi
        echo "No Android USB device detected."; exit 1
      fi
      echo "== ADB devices =="; printf '%s\n' "$lines"
      if printf '%s\n' "$lines" | grep -q unauthorized; then echo "Unlock phone and accept the RSA prompt."; exit 3; fi
      count=$(printf '%s\n' "$lines" | grep -c '[[:space:]]device[[:space:]]' || true)
      [ "$count" -eq 1 ] || { echo "Expected exactly one authorized device; found $count."; exit 4; }
      serial=$(printf '%s\n' "$lines" | awk '$2 == "device" {print $1}')
      echo "Authorized serial: $serial"
      adb -s "$serial" shell getprop ro.product.model
      adb -s "$serial" shell dumpsys package ${androidPackage} 2>/dev/null | grep -E 'version(Name|Code)=' || echo "FEH is not installed or package metadata is inaccessible."
    '';
  };

  samsungRecover = pkgs.writeShellApplication {
    name = "feh-samsung-recover";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      scrcpy
    ];
    text = ''
      serial="''${1:-}"
      if [ -z "$serial" ]; then
        mapfile -t devices < <(adb devices | awk '$2 == "device" {print $1}')
        [ "''${#devices[@]}" -eq 1 ] || { echo "Pass SERIAL when exactly one device is not authorized." >&2; exit 2; }
        serial="''${devices[0]}"
      fi
      out="''${XDG_STATE_HOME:-$HOME/.local/state}/feh-waydroid/samsung/$(date -u +%Y%m%dT%H%M%SZ)"
      mkdir -p "$out"
      adb -s "$serial" shell getprop >"$out/getprop.txt"
      adb -s "$serial" shell dumpsys package ${androidPackage} >"$out/feh-package.txt" 2>&1 || true
      adb -s "$serial" shell monkey -p ${androidPackage} -c android.intent.category.LAUNCHER 1 || true
      echo "Use FEH Account Management to link the intended Nintendo Account. No private app data will be copied."
      exec scrcpy --serial "$serial"
    '';
  };
in
{
  options.services.fehWaydroid = {
    enable = lib.mkEnableOption "Waydroid environment for Fire Emblem Heroes";
    user = lib.mkOption {
      type = lib.types.str;
      default = "warby";
    };
    width = lib.mkOption {
      type = lib.types.ints.positive;
      default = 720;
    };
    height = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1280;
    };
    useNftables = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.waydroid.enable = true;
    networking.nftables.enable = lib.mkIf cfg.useNftables true;
    users.users.${cfg.user}.extraGroups = [ "adbusers" ];
    programs.adb.enable = true;

    environment.systemPackages = [
      pkgs.android-tools
      pkgs.scrcpy
      pkgs.usbutils
      pkgs.waydroid-helper
      fehWaydroid
      hostCheck
      bootstrap
      armTranslation
      deviceId
      doctor
      gameplayTest
      androidDevice
      samsungRecover
    ];

    environment.etc."waydroid/waydroid_base.prop".text = ''
      ro.hardware.gralloc=default
      ro.hardware.egl=swiftshader
      persist.waydroid.width=${toString cfg.width}
      persist.waydroid.height=${toString cfg.height}
      persist.waydroid.multi_windows=true
    '';

    environment.etc."xdg/applications/feh-waydroid.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Fire Emblem Heroes (Waydroid)
      Exec=feh-waydroid play
      Icon=applications-games
      Categories=Game;
      Terminal=false
    '';

    environment.etc."xdg/applications/waydroid-play-store.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Google Play (Waydroid)
      Exec=feh-waydroid store
      Icon=system-software-install
      Categories=System;
      Terminal=false
    '';
  };
}
