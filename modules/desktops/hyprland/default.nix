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
        my.hyprland.enable = lib.mkEnableOption "Enable hyprland module";
      };
      config = lib.mkIf config.my.hyprland.enable {
        my.hypr.enable = lib.mkDefault true;
        # Bar selection based on host.bar option
        my.bars = {
          noctalia.enable = lib.mkIf (osConfig.host.bar == "noctalia") true;
        };
        my.hyprlock.enable = lib.mkDefault true;
        my.hyprpaper.enable = lib.mkDefault true;
        my.wlogout.enable = lib.mkDefault true;
      };
    };
}
