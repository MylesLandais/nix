# ============================================================================
# Home Manager Configuration - User Environment Setup
# ============================================================================
#
# This file configures the user environment using Home Manager, providing
# a declarative way to manage user-specific packages, dotfiles, and settings.
#
# STRUCTURE:
# ==========
# - imports: Modular configurations and external modules
# - home: Core user information and state management
# - programs: Application-specific configurations
# - xdg: XDG Base Directory compliance
# - qt/stylix: Theming and appearance
#
# MODULAR IMPORTS:
# ================
# - ./modules/pro.nix: Professional creative tools
# - stylix: System-wide theming
# - tokyonight: Color scheme for supported applications
#
# KEY FEATURES:
# =============
# - User packages: Comprehensive toolset for development and productivity
# - Browser configuration: Brave with extensions and custom preferences
# - Terminal theming: Ghostty with Kanagawa theme
# - File associations: Default applications for various MIME types
# - GTK theming: Kanagawa theme with Bibata cursors
#
# MAINTENANCE:
# ============
# - Update home.stateVersion when upgrading NixOS versions
# - Use home-manager switch to apply changes
# - Backup existing configs before major changes
#
# ============================================================================

{
  pkgs,
  lib,
  vars,
  config,
  inputs,
  ...
}:
{

  # Home Manager needs a bit of information about you and the paths it should
  # manage.

  imports = [
    ##./hypr.nix
    ## ./nixvim
    ##./hyprpanel.nix
    ./modules/pro.nix                    # Professional creative tools
    inputs.stylix.homeModules.stylix     # System theming
    inputs.tokyonight.homeManagerModules.default  # Color schemes
  ];

  home = {
    username = vars.username;
    enableNixpkgsReleaseCheck = false;
    homeDirectory = "/home/${vars.username}";
    stateVersion = "24.11"; # Please read the comment before changing.
    file = {
        "${config.xdg.configHome}/ghostty/config".text = ''
          theme = "Kanagawa Dragon"
          background-opacity = 0.9
          window-decoration = false
          font-family = "JetBrainsMono Nerd Font"
          '';

          ".config/code-server/config.yaml".text = ''
bind-addr: 0.0.0.0:8080
auth: password
password: admin  # Matches container env; secure with agenix
cert: false
          '';





    };

    sessionVariables = {
      # EDITOR = "emacs";
    };

    packages = with pkgs; [
      # jetbrains.goland
      bind
      bitwarden-desktop
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
          "text/html" = [ "brave-browser.desktop" ];
          "x-scheme-handler/http" = [ "brave-browser.desktop" ];
          "x-scheme-handler/https" = [ "brave-browser.desktop" ];
          "x-scheme-handler/about" = [ "brave-browser.desktop" ];
          "x-scheme-handler/unknown" = [ "brave-browser.desktop" ];
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
          background = "0d0c0cfa";  # base00 with alpha
          text = "c5c9c5ff";      # base05
          border = "c4b28aff";     # base0A
          selection = "8ba4b0ff";  # base0D
          selection-text = "0d0c0cff"; # base00
        };
      };
    };
        brave = {
          enable = true;
          commandLineArgs = [
            "--enable-features=WebUIDarkMode"
            "--force-dark-mode"
          ];
          extensions = [
            { id = "akibfjgmcjogdlefokjmhblcibgkndog"; }  # Shazam
            { id = "djnghjlejbfgnbnmjfgbdaeafbiklpha"; }  # Kanagawa Theme
            { id = "nngceckbapebfimnlniiiahkandclblb"; }  # Bitwarden
            { id = "mmioliijnhnoblpgimnlajmefafdfilb"; }  # SponsorBlock
          ];
        };
    firefox = {
        enable = true;
        profiles.default = {
            isDefault = true;
        };
    };

    vscode = {
      enable = true;
      package = pkgs.vscode;
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          bbenoist.nix
          ms-vscode-remote.remote-containers
          ms-vscode-remote.remote-ssh
          redhat.vscode-yaml
          # kilocode.kilo-code  # Not in nixpkgs; install manually from marketplace
          # quinn.vscode-kanagawa  # Not in nixpkgs; install manually from marketplace
        ];
        userSettings = {
          "workbench.colorTheme" = "Kanagawa";  # Set after manual extension install
          "editor.fontFamily" = "JetBrains Mono Nerd Font";
          "terminal.integrated.fontFamily" = "JetBrains Mono Nerd Font";
          # "kilo-code.apiKey" = "your-kilo-code-api-key";  # Set after manual install
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
      gtk.enable = true;
      mpv.enable = true;
      vesktop.enable = true;
    };
  };
}
