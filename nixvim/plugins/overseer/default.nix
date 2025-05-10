{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    overseer.enable = lib.mkEnableOption "Enable overseer nixvim plugin module";
  };

  config = lib.mkIf config.overseer.enable {
    programs.nixvim.plugins.overseer = {
      enable = true;
    };
  };
}
