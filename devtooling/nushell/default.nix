{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    nushell.enable = lib.mkEnableOption "Enable nushell module";
  };

  config = lib.mkIf config.nushell.enable {
    programs.nushell = {
      enable = true;
    };
  };
}
