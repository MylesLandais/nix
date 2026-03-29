{
  lib,
  config,
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
        background = "#12141c";
        foreground = "#b9c6ce";
        cursor-color = "#b9c6ce";
        selection-background = "#12141c";
        selection-foreground = "#b9c6ce";
        palette = [
          "0=#12141c"
          "1=#4D5360"
          "2=#546876"
          "3=#BB6968"
          "4=#627985"
          "5=#708995"
          "6=#7C97A4"
          "7=#b9c6ce"
          "8=#818a90"
          "9=#4D5360"
          "10=#546876"
          "11=#BB6968"
          "12=#627985"
          "13=#708995"
          "14=#7C97A4"
          "15=#b9c6ce"
        ];
      };
    };
  };
}
