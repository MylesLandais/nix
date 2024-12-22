{pkgs, lib, config, ...}:
{

  options = {
    bat.enable = lib.mkEnableOption "Enable bat module";
  };

  config = lib.mkIf config.direnv.enable {
    programs.bat = {
      enable = true;
    };

  };

}
