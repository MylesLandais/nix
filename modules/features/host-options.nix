{ lib, ... }:
{
  options.host = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of this machine.";
    };
    isDesktop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this machine is a desktop.";
    };
    class = lib.mkOption {
      type = lib.types.enum [
        "laptop"
        "desktop"
      ];
      description = "The class of this machine.";
    };
    bar = lib.mkOption {
      type = lib.types.enum [
        "noctalia"
        "caelestia"
        "hyprpanel"
      ];
      description = "The desktop bar/panel to use.";
    };
    greeter = lib.mkOption {
      type = lib.types.enum [
        "sddm"
        "greetd"
      ];
      default = "greetd";
      description = "The display manager / greeter to use.";
    };
    gpuType = lib.mkOption {
      type = lib.types.enum [
        "amd"
        "nvidia"
        "none"
      ];
      default = "none";
      description = "GPU type for acceleration packages (amd=ROCm, nvidia=CUDA, none=CPU-only).";
    };
    theme = lib.mkOption {
      type = lib.types.enum [
        "kanagawa-dragon"
        "kanagawa-wave"
        "kanagawa-aqua"
      ];
      default = "kanagawa-dragon";
      description = "System color theme variant.";
    };
    themeData = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "Computed theme values derived from host.theme. Set by nixosModules.themeData.";
    };
    wallpaper = lib.mkOption {
      type = lib.types.path;
      description = "Path to the wallpaper image.";
    };
    mainMonitor = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          width = lib.mkOption { type = lib.types.str; };
          height = lib.mkOption { type = lib.types.str; };
          refresh = lib.mkOption { type = lib.types.str; };
        };
      };
      description = "Primary monitor configuration.";
    };
    secondaryMonitor = lib.mkOption {
      type = lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          width = lib.mkOption { type = lib.types.str; };
          height = lib.mkOption { type = lib.types.str; };
          refresh = lib.mkOption { type = lib.types.str; };
        };
      };
      description = "Secondary monitor configuration.";
    };
    profile = lib.mkOption {
      type = lib.types.enum [
        "default"
        "pentest"
        "gaming"
      ];
      default = "default";
      description = "Host workload profile (latitudes imaged off lacie flip this to pentest).";
    };
    imaging = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable the portable-USB imaging feature module (systemd-boot, by-label fs, no NVRAM writes).";
      };
      mode = lib.mkOption {
        type = lib.types.enum [
          "ventoy"
          "amnesic"
        ];
        default = "ventoy";
        description = "ventoy: persistent root on live_nix. amnesic: tmpfs root + /persist (deferred).";
      };
      homeLabel = lib.mkOption {
        type = lib.types.str;
        default = "live_nix";
        description = "Filesystem label for the NixOS root (ventoy mode) or /persist partition (amnesic mode).";
      };
      imagesLabel = lib.mkOption {
        type = lib.types.str;
        default = "images";
        description = "Filesystem label for the exFAT images partition.";
      };
      shareLabel = lib.mkOption {
        type = lib.types.str;
        default = "persistent_data";
        description = "Filesystem label for the NTFS bulk-share partition (kept NTFS for Windows interop).";
      };
      homeLuks = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Future: wrap home/persist in LUKS. Wired but not active in ventoy mode.";
      };
    };
  };
}
