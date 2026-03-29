{
  lib,
  config,
  osConfig,
  ...
}:
{
  options.ghostty.enable = lib.mkEnableOption "Enable ghostty terminal";

  config = lib.mkIf config.ghostty.enable {
    programs.ghostty = {
      enable = true;
      settings = {
        font-family = "Maple Mono NF";
        background-opacity = 0.9;
        window-decoration = false;
        background = osConfig.host.themeData.ghostty.background;
        foreground = osConfig.host.themeData.ghostty.foreground;
        cursor-color = osConfig.host.themeData.ghostty.cursorColor;
        selection-background = osConfig.host.themeData.ghostty.selectionBackground;
        selection-foreground = osConfig.host.themeData.ghostty.selectionForeground;
        palette = osConfig.host.themeData.ghostty.palette;
      };
    };
  };
}
