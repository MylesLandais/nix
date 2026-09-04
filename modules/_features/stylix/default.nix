{
  lib,
  config,
  osConfig,
  ...
}:
{
  options = {
    stylix-mod.enable = lib.mkEnableOption "Enable stylix module";
  };
  config = lib.mkIf config.stylix-mod.enable {
    stylix = {
      autoEnable = false;
      enable = true;
      inherit (osConfig.host.themeData) base16Scheme;
      polarity = "dark";
      icons.dark = "Papirus-Dark";
      targets = {
        bat.enable = true;
        btop.enable = true;
        # Was false while pkgs.kanagawa-gtk-theme supplied the widget theme. That
        # package was removed from nixpkgs (it needed gtk-engine-murrine, dropped as
        # an unmaintained GTK2 dependency), so stylix now generates the GTK theme
        # from the same Kanagawa base16Scheme above — the colours are identical, only
        # the widget styling comes from stylix rather than hand-crafted Kanagawa-B.
        gtk.enable = true;
        qt.enable = true;
        hyprland.enable = true;
        # stylix dropped its hyprpanel target upstream (gone as of the 2026-08-08
        # bump). The bar is themed through modules/_features/bars/hyprpanel.nix.
        k9s.enable = true;
        kubecolor.enable = true;
        lazygit.enable = true;
        mpv.enable = true;
        opencode.enable = true;
        # Noctalia regenerates colors.json from the wallpaper at runtime.
        # Enabling this target makes that file a read-only Nix store symlink,
        # causing its template processor to fail on every session start.
        noctalia-shell.enable = false;
        vesktop.enable = true;
        wofi.enable = true;
      };
    };
  };
}
