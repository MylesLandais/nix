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
  userEmail = "myles.landais@protonmail.com";

  isDesktop = true;
  wallpaper = "${wp}/share/wallpapers/nix-wallpaper-nineish-catppuccin-mocha.png";

  mainMonitor = {
    name = "desc:Dell Inc. Dell S2716DG ##ASPYT+r5vCzd";
    width = 2560;
    height = 1440;
    refresh = 59.95;
  };

  secondaryMonitor = {
    name = "desc:Dell Inc. DELL P2422H 46Z5YB3";
    width = 1920;
    height = 1080;
    refresh = 60.0;
  };

  tertiaryMonitor = {
    name = "desc:Dell Inc. DELL P2422H 62K3NK3";
    width = 1920;
    height = 1080;
    refresh = 60.0;
  };

  fourthMonitor = {
    name = "desc:Samsung Electric Company SAMSUNG 0x01000E00";
    width = 1920;
    height = 1080;
    refresh = 29.97;
  };
}
