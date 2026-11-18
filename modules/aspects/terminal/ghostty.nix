{
  flake.modules.homeManager.terminals =
    {
      lib,
      config,
      osConfig,
      ...
    }:
    {
      options.my.ghostty.enable = lib.mkEnableOption "Enable ghostty terminal";

      config = lib.mkIf config.my.ghostty.enable {
        programs.ghostty = {
          enable = true;
          settings = {
            font-family = [
              "Atkinson Hyperlegible Mono"
              "Symbols Nerd Font Mono"
            ];
            font-family-italic = "Maple Mono";
            font-family-bold-italic = "Maple Mono";
            font-feature = [
              "-calt"
              "-liga"
            ];
            adjust-cell-height = "15%";
            cursor-style = "block";
            cursor-style-blink = false;
            background-opacity = 0.9;
            window-decoration = false;
            # Leave fullscreen to the compositor and Ctrl+Enter to terminal apps.
            keybind = [ "ctrl+enter=unbind" ];
            inherit (osConfig.host.themeData.ghostty) background;
            inherit (osConfig.host.themeData.ghostty) foreground;
            cursor-color = osConfig.host.themeData.ghostty.cursorColor;
            selection-background = osConfig.host.themeData.ghostty.selectionBackground;
            selection-foreground = osConfig.host.themeData.ghostty.selectionForeground;
            inherit (osConfig.host.themeData.ghostty) palette;
          };
        };
      };
    };
}
