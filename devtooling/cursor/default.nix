{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  options.cursor.enable = lib.mkEnableOption "Enable Cursor AI IDE";

  config = lib.mkIf config.cursor.enable {
    home.packages = [
      pkgs.code-cursor
      inputs.llm.packages.${pkgs.system}.cursor-agent
    ];
  };
}
