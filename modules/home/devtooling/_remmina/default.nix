{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    remmina.enable = lib.mkEnableOption "Remmina remote desktop client (VNC, RDP, SSH)";
  };

  config = lib.mkIf config.remmina.enable {
    home.packages = with pkgs; [
      remmina
    ];
  };
}
