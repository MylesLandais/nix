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
  };
}
