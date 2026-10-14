{ config, lib, pkgs, ... }:
let
  cfg = config.games_.diagnostics;
  desktopAudit = pkgs.writeShellApplication {
    name = "desktop-session-audit";
    runtimeInputs = with pkgs; [
      coreutils desktop-file-utils findutils gnugrep gnused jq systemd util-linux
    ];
    text = builtins.readFile ../../../scripts/desktop-session-audit.sh;
  };
  warcraftAudit = pkgs.writeShellApplication {
    name = "warcraft3-linux-audit";
    runtimeInputs = with pkgs; [
      coreutils findutils gnugrep gnused util-linux vulkan-tools
    ];
    text = builtins.readFile ../../../scripts/warcraft3-linux-audit.sh;
  };
in
{
  options.games_.diagnostics.enable = lib.mkEnableOption "read-only gaming and desktop-session diagnostics";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ desktopAudit warcraftAudit ];
  };
}
