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
    buildPhase=''
      echo ""
    '';
  };
in
{
  hostName = "cerberus-nix";
  username = "warby";
  userEmail = "warby@example.com";

  isDesktop = true;
  wallpaper = "${wp}/share/wallpapers/nix-wallpaper-nineish-catppuccin-mocha.png";

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
