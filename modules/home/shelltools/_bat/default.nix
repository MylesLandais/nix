{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    my.bat.enable = lib.mkEnableOption "Enable bat module";
  };

  config = lib.mkIf config.my.direnv.enable {
    programs.bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batdiff
        batman
        prettybat
      ];
    };
  };
}
