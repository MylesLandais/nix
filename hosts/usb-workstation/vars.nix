{
  pkgs,
  ...
}:
let
  wp = pkgs.stdenv.mkDerivation rec {
    pname = "wallpapers";
    version = "v1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "NixOS";
      repo = "nixos-artwork";
      rev = "9d2cdedd73d64a068214482902adea3d02783ba8";
      hash = "sha256-//4BiRF1W5W2rEbw6MupiyDOjvcveqGtYjJ1mZfck9U=";
    };
    buildInputs = [ pkgs.imagemagick ];
    installPhase = ''
      mkdir -p $out/share/wallpapers
      cp -r ${src}/wallpapers/* $out/share/wallpapers
    '';
    buildPhase = ''
      echo ""
    '';
  };
in
{
  hostName = "usb-workstation";
  username = "warby";
  userEmail = "myles.landais@protonmail.com";

  isDesktop = true;
  wallpaper = "${wp}/share/wallpapers/nix-wallpaper-nineish-catppuccin-mocha.png";

  # Portable: empty name = Hyprland wildcard (matches any unrecognized monitor).
  # Positions and workspace bindings are overridden in hosts/usb-workstation/home.nix.
  mainMonitor = { name = ""; width = 1920; height = 1080; refresh = 60.0; };
  secondaryMonitor = { name = ""; width = 1920; height = 1080; refresh = 60.0; };
  tertiaryMonitor = { name = ""; width = 1920; height = 1080; refresh = 60.0; };
  fourthMonitor = { name = ""; width = 1920; height = 1080; refresh = 60.0; };
}
