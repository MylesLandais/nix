{
  pkgs,
  lib,
  config,
  inputs,
  gpuType ? "none",
  ...
}:
let
  chromiumBrowsers = import ./chromium-browsers.nix { inherit lib; };
  inherit (chromiumBrowsers)
    mkChromiumFlags
    chromiumStandardBrowserFlags
    ;

  vaapiMode =
    if gpuType == "nvidia" then
      "nvidia"
    else if gpuType == "amd" then
      "generic"
    else
      false;

  chromiumFlagsFile = mkChromiumFlags (chromiumStandardBrowserFlags // { inherit vaapiMode; });

  # Helium and Vivaldi both still show blocky WebM/GIF artifacts on nvidia
  # even with UseChromeOSDirectVideoDecoder disabled; fall back to software
  # decode (fallback ladder rung 3 in chromium-browsers.nix) for both.
  # Chromium proper has not shown the issue, so it keeps hardware decode.
  softwareDecodeFlagsFile = mkChromiumFlags (chromiumStandardBrowserFlags // { vaapiMode = false; });
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.

  imports = [
    ./features/desktops/hyprland
    ./features/desktops/niri
    ./features/desktops/xfce
    ./features/bars
    ./features/prompt
    ./features/shelltools
    ./features/devtooling
    ./features/gtk
    ./features/terminals
    ./features/stylix
    ./features/flameshot.nix
    ./features/ssh-bitwarden.nix
    ./firefox.nix
    inputs.stylix.homeModules.stylix
    inputs.noctalia.homeModules.default
    inputs.tokyonight.homeManagerModules.default
  ];
  fonts.fontconfig.enable = true;

  home = {
    username = "franky";
    enableNixpkgsReleaseCheck = false;
    homeDirectory = "/home/franky";
    stateVersion = "24.11"; # Please read the comment before changing.
    sessionVariables = {
      OZONE_PLATFORM = "wayland";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      EDITOR = "nvim";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
    };

    file = {
      "${config.xdg.configHome}/helium-flags.conf".text = softwareDecodeFlagsFile;
      "${config.xdg.configHome}/chromium-flags.conf".text = chromiumFlagsFile;
      "${config.xdg.configHome}/vivaldi-flags.conf".text = softwareDecodeFlagsFile;
    };

    packages = import ./packages.nix { inherit pkgs; };
    pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 22;
    };
  };

  # Custom modules
  prompt.enable = true;
  devtooling.enable = true;
  shelltools.enable = true;
  stylix-mod.enable = true;
  gtk-mod.enable = true;
  hyprland.enable = true;
  terminals.enable = true;

  # Gammastep: auto-adjust screen color temperature for eye fatigue reduction.
  # Uses wayland backend for Hyprland. Coordinates default to Chicago (cerberus).
  # Override per-host via hosts/<name>/home.nix if needed.
  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = 41.9;
    longitude = -87.6;
    temperature = {
      day = 6500;
      night = 3500;
    };
    settings = {
      general = {
        adjustment-method = "wayland";
        brightness-day = 1.0;
        brightness-night = 0.9;
      };
    };
  };

  # Minimal programs configuration
  programs = {
    home-manager.enable = true;
    firefox.enable = true;
    # Extensions and policies for Helium / Chromium come from chromiumPolicies
    # on Cerberus (see hosts/cerberus/configuration.nix).
    chromium.enable = true;
    btop = {
      enable = true;
      settings = {
        theme_background = false;
      };
    };
    git = {
      delta.tokyonight.enable = false;
      lfs.enable = true;
    };
    onlyoffice.enable = true;
    wofi.enable = false;

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "Hack Nerd Font";
          prompt = ''">    "'';
          lines = 20;
          width = 60;
          horizontal-pad = 40;
          vertical-pad = 16;
          inner-pad = 6;
        };
        colors = {
          background = "1e1e2efa";
          text = "19617813801";
          border = "#c4b28a";
        };
      };
    };
  };

}
