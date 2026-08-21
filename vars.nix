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
  hostName = "cerberus-nix";
  username = "warby";
  userEmail = "myles.landais@protonmail.com";

  isDesktop = true;
  wallpaper = "${wp}/share/wallpapers/nix-wallpaper-nineish-catppuccin-mocha.png";

  mainMonitor = {
    name = "desc:Dell Inc. Dell S2716DG #ASPYT+r5vCzd";
    width = 2560;
    height = 1440;
    refresh = 144.0;
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

  # The TV. Its EDID declares "Maximum TMDS clock: 300 MHz" -- the HDMI 1.4
  # ceiling -- so 4K is only ever offered at 30 Hz or below; 4K60 would need
  # 594 MHz. That held on every input tried, so 4K30 is the hardware ceiling,
  # not a setting waiting to be found.
  #
  # 1080p60 is the better half of that trade: retro content is 60 Hz native, and
  # 4K buys nothing for 240p/480p sources that get upscaled anyway. `tv-mode 4k`
  # switches live if sharpness ever matters more than motion.
  #
  # bitdepth 8 is load-bearing, not cosmetic: together with 1080p it is what
  # fixed the TV failing to wake until a session had fully loaded. Commit 8716cf8
  # carried the resolution over from the old nwg-displays config but dropped the
  # bitdepth; this restores it.
  fourthMonitor = {
    name = "desc:Samsung Electric Company SAMSUNG 0x01000E00";
    width = 1920;
    height = 1080;
    refresh = 60.0;
    bitdepth = 8;
  };
}
