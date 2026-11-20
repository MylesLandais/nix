# herdr: agent-aware terminal workspace manager (tmux for coding agents).
# Packaged in nixpkgs; matches the latest upstream release, so no extra flake input.
# Config reference: https://herdr.dev/tui/docs/config-reference/
{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1160 {
    imports = [
      (
        {
          lib,
          config,
          ...
        }:
        {
          options = {
            my.herdr.enable = lib.mkEnableOption "Enable herdr module";
          };
          config = lib.mkIf config.my.herdr.enable {
            programs.herdr = {
              enable = true;
              # Let herdr save UI toggles back to config.toml while Nix keeps
              # the settings below merged in on activation.
              mutableSettings = true;
              # Updates come from flake bumps of nixpkgs, so silence herdr's
              # background checks against herdr.dev.
              settings.update = {
                version_check = false;
                manifest_check = false;
              };
            };
            # herdr is a TUI and ships no .desktop file, so launchers (fuzzel)
            # can't see it. Wrap it in the default terminal instead.
            xdg.desktopEntries.herdr = {
              name = "Herdr";
              comment = "Agent-aware terminal workspace manager";
              exec = "ghostty -e herdr";
              categories = [ "Development" ];
              startupNotify = false;
            };
          };
        }
      )
    ];
  };
}
