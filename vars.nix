{
  hostName = "cerberus-nix";
  username = "warby";
  userEmail = "warby@example.com";

  isDesktop = true;
  wallpaper = "https://github.com/NixOS/nixos-artwork/raw/master/wallpapers/nix-wallpaper-nineish-catppuccin-mocha.png";

  mainMonitor = {
    name = "DP-1";
    width = 2560;
    height = 1440;
    refresh = 144;
  };

  secondaryMonitor = {
    name = "HDMI-A-1";
    width = 1920;
    height = 1080;
    refresh = 60;
  };
}
