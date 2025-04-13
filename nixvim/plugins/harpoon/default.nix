{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    harpoon.enable = lib.mkEnableOption "Enable harpoon nixvim plugins module";
  };

  config = lib.mkIf config.harpoon.enable {
    programs.nixvim.plugins = {
      harpoon = {
        enable = true;
        enableTelescope = true;
      };
    };
  };
}
