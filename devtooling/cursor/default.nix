{ config, lib, pkgs, ... }:
{
  options.cursor.enable = lib.mkEnableOption "Enable Cursor AI IDE";

  config = lib.mkIf config.cursor.enable {
    home.packages = [ pkgs.code-cursor ];
  };
}
