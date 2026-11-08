_: {
  flake.modules.homeManager.hyprland =
    {
      lib,
      config,
      osConfig,
      ...
    }:
    {
      imports = [
        ./_hypr.nix
        ./_hyprlock.nix
        ./_hyprpaper.nix
        ./_wlogout.nix
        ./_workspace-recovery.nix
        ./_prompt-follow-focus.nix
      ];

      options = {
        hyprland.enable = lib.mkEnableOption "Enable hyprland module";
      };
      config = lib.mkIf config.hyprland.enable {
        hypr.enable = lib.mkDefault true;
        # Bar selection based on host.bar option
        bars = {
          noctalia.enable = lib.mkIf (osConfig.host.bar == "noctalia") true;
        };
        hyprlock.enable = lib.mkDefault true;
        hyprpaper.enable = lib.mkDefault true;
        wlogout.enable = lib.mkDefault true;
      };
    };
}
