{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    my.kubernetes.enable = lib.mkEnableOption "Enable kubernetes option";
  };
  config = lib.mkIf config.my.kubernetes.enable {
    home.packages = with pkgs; [
      kubectl
    ];
    programs.k9s = {
      enable = true;
    };
  };
}
