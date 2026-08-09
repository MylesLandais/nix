# Hermes agent launcher entries, desktop icon, and dashboard theme.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.hermesDesktop;
in
{
  options.hermesDesktop = {
    enable = lib.mkEnableOption "Hermes terminal/desktop launchers and dashboard theme";
  };

  config = lib.mkIf cfg.enable {
    home.file.".local/share/applications/hermes.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Hermes (Terminal)
      GenericName=AI Agent
      Comment=Hermes ACP terminal agent
      Exec=ghostty -e hermes
      Terminal=false
      Icon=utilities-terminal
      Categories=Development;Utility;
    '';

    home.file.".local/share/icons/hicolor/512x512/apps/hermes-desktop.png".source = "${
      inputs.hermes-agent.packages.${pkgs.system}.desktop
    }/share/hermes-desktop/dist/hermes.png";

    home.file.".local/share/applications/hermes-desktop.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Hermes Desktop
      GenericName=AI Agent
      Comment=Hermes GUI desktop app
      Exec=hermes-desktop
      Terminal=false
      Icon=hermes-desktop
      StartupWMClass=hermes
      Categories=Development;Utility;
    '';

    home.file.".hermes/dashboard-themes/kanagawa.yaml".text = ''
      name: kanagawa
      label: Kanagawa Dragon
      description: System theme -- matches Stylix's Kanagawa Dragon base16 scheme
      palette:
        background:
          hex: "#181616" # base00
          alpha: 1
        midground:
          hex: "#c5c9c5" # base05
          alpha: 1
        foreground:
          hex: "#ffffff"
          alpha: 0
        warmGlow: "rgba(139, 164, 176, 0.32)" # base0D
        noiseOpacity: 0.8
      typography:
        fontSans: "Maple Mono NF, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
        fontMono: "Maple Mono NF, ui-monospace, Menlo, Consolas, monospace"
        baseSize: "15px"
        lineHeight: "1.55"
        letterSpacing: "0"
      layout:
        radius: "0.5rem"
        density: comfortable
      colorOverrides:
        destructive: "#c4746e" # base08
        warning: "#c4b28a"     # base0A
        success: "#8a9a7b"     # base0B
        accent: "#8ba4b0"      # base0D
        ring: "#8ba4b0"        # base0D
        border: "#393836"      # base02
        muted: "#282727"       # base01
        mutedForeground: "#737c73" # base04
      terminalBackground: "#181616" # base00
    '';
  };
}
