{
  pkgs,
  lib,
  vars,
  config,
  inputs,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;

  # Home Manager needs a bit of information about you and the paths it should
  # manage.

  imports = [
    ##./hypr.nix
    ## ./nixvim
    ##./hyprpanel.nix
    inputs.stylix.homeModules.stylix
    inputs.tokyonight.homeManagerModules.default
  ];

  home = {
    username = "warby";
    enableNixpkgsReleaseCheck = false;
    homeDirectory = "/home/warby";
    stateVersion = "24.11"; # Please read the comment before changing.
    file = {
      "${config.xdg.configHome}/ghostty/config".text = ''
        theme = "Kanagawa Dragon"
        background-opacity = 0.9
        window-decoration = false
        font-family = "JetBrainsMono Nerd Font"
      '';
    };

    sessionVariables = {
      # EDITOR = "emacs";
    };

    packages = with pkgs; [
      # jetbrains.goland
      bind
      bitwarden-desktop
      brave
      btop
      calibre
      calibre-web
      coreutils
      nemo
      fastfetch
      fd
      ffmpeg
      fishPlugins.forgit
      gamemode
      gcc
      gh
      git-lfs
      gnome-keyring
      gnome-secrets
      gnome-themes-extra
      gpgme
      gtk-engine-murrine
      hack-font
      heroic
      jetbrains-mono
      jq
      kanagawa-gtk-theme
      kanagawa-icon-theme
      lazydocker
      lazygit
      libnotify
      markdown-oxide
      matugen
      mpv
      nix-search-tv
      nixos-generators
      nwg-look
      obsidian
      opencloud-desktop
      pavucontrol
      playerctl
      plex-desktop
      plex-mpv-shim
      pulseaudio
      pulseaudio-ctl
      pulsemixer
      revive
      ripgrep
      sassc
      statix
      terraform-ls
      tflint
      tldr
      tokyonight-gtk-theme
      treefmt
      ttyd
      vesktop
      vhs
      virtualgl
      vulkan-tools
      wl-clipboard
      zed-editor
    ];
    pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 22;
    };
  };

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/about" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/unknown" = [ "chromium-browser.desktop" ];
        "x-scheme-handler/discord" = [ "vesktop.desktop" ];
      };
    };
  };

  programs = {
    home-manager.enable = true;
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

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "qt6gtk2";
  };
  stylix = {
    autoEnable = false;
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa-dragon.yaml";
    targets = {
      bat.enable = true;
      btop.enable = true;
      gtk.enable = false;
      mpv.enable = true;
      vesktop.enable = true;
    };
  };
}
