{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    remmina.enable = lib.mkEnableOption "Enable remmina module";
  };
  config = lib.mkIf config.remmina.enable {
    home.packages = with pkgs; [
      remmina
    ];
  };
}