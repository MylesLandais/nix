# The sibling module priorities retain the original import order and configuration precedence.
_: {
  flake.modules.homeManager.hyprland =
    {
      lib,
      config,
      osConfig,
      ...
    }:
    {

      options = {
        my.hyprland.enable = lib.mkEnableOption "Enable hyprland module";
      };
      config = lib.mkIf config.my.hyprland.enable {
        my.hypr.enable = lib.mkDefault true;
        # Bar selection based on host.bar option
        my.bars = {
          noctalia.enable = osConfig.host.bar == "noctalia";
        };
        my.hyprlock.enable = lib.mkDefault true;
        my.hyprpaper.enable = lib.mkDefault true;
        my.wlogout.enable = lib.mkDefault true;
      };
    };
}
