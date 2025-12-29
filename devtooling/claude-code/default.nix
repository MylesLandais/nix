{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    claude-code.enable = lib.mkEnableOption "Enable Claude Code CLI module";
  };

  config = lib.mkIf config.claude-code.enable {
    home.packages = with pkgs; [ pkgs.claude-code ];
  };
}
