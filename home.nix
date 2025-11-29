{
  pkgs,
  lib,
  vars,
  config,
  inputs,
  self,
  ...
}:
{
  imports = [
    ./hypr.nix
    # ./nixvim  # Temporarily disabled
    ./hyprpanel.nix
    ./modules/pro.nix # Professional creative tools
    ./modules/firefox.nix # Firefox configuration
    ./shelltools
    ./devtooling
    inputs.stylix.homeModules.stylix # System theming
    inputs.tokyonight.homeManagerModules.default # Color schemes
  ];

  fonts.fontconfig.enable = true;

  home = {
    inherit (vars) username;
    enableNixpkgsReleaseCheck = false;
    homeDirectory = "/home/${vars.username}";
    stateVersion = "24.11"; # Please read the comment before changing.



    file = {
      "${config.xdg.configHome}/ghostty/config".text = ''
        theme = "Kanagawa Dragon"
        background-opacity = 0.9
        window-decoration = false
        font-family = "'Maple Mono NF', JetBrainsMono Nerd Font'"
      '';

      "${config.xdg.configHome}/electron-flags.conf".text = ''
        --ozone-platform=wayland
        --enable-features=WaylandWindowDecorations
      '';

      ".config/code-server/config.yaml".text = ''
        bind-addr: 0.0.0.0:8080
        auth: password
        password: admin  # Matches container env; secure with agenix
        cert: false
      '';

      ".config/code-server/settings.json".text = ''
        {
          "workbench.colorTheme": "Kanagawa",
          "editor.fontFamily": "JetBrains Mono Nerd Font",
          "terminal.integrated.fontFamily": "JetBrains Mono Nerd Font"
        }
      '';

    };

    sessionVariables = {
      TERMINAL = "ghostty";
      EDITOR = "nvim";
    };

    # Shell aliases for build-time sleep inhibition
    shellAliases = {
      nixos-rebuild-awake = "gnome-session-inhibit --inhibit idle sudo nixos-rebuild";
      nix-build-awake = "gnome-session-inhibit --inhibit idle nix build";
    };


    packages = with pkgs; [
      # Additions for declarative archive handling in Nemo and CLI
      bind
      bitwarden-desktop
      btop
      coreutils
      fastfetch
      fd
      ffmpeg
      file-roller # GNOME archive manager
      fishPlugins.forgit
      font-awesome
      gamemode
      gcc
      gemini-cli
      goose-cli
      gh
      ghostty
      git-lfs
      gnome-themes-extra
      gpgme
      grim
      gtk-engine-murrine
      hack-font
      heroic
      hyprpicker
      jetbrains-mono
      jq
      kanagawa-gtk-theme
      kanagawa-icon-theme
      lazydocker
      lazygit
      libnotify
      markdown-oxide
      matugen
      nemo
      nemo-fileroller # Nemo extension for context menu integration
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      maple-mono.truetype
      maple-mono.NF-unhinted
      nix-search-tv
      nixos-generators
      nodejs_20 # Required for discord-ai-bot-lmstudio project (Node.js >=20.11.0)
      nwg-look
      obsidian
      opencloud-desktop
      opencode
      p7zip # Provides '7z' for .zip, .7z, etc.
      pavucontrol
      (hyprshot.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/hyprshot \
            --set HYPRSHOT_DIR "/home/${vars.username}/Pictures/Screenshots" \
            --set BORDER_COLOR "#c4b28aff" \
            --set BACKGROUND_COLOR "#18161600"
        '';
      }))
      playerctl
      plex-mpv-shim
      pulseaudio
      pulseaudio-ctl
      pulsemixer
      qt6Packages.qt6ct
      revive
      ripgrep
      sassc
      slurp
      statix
      terraform-ls
      tflint
      tldr
      treefmt
      tree
      ttyd
      unzip # Basic .zip support
      unrar
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

  devtooling.enable = true;
  shelltools.enable = true;
  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "x-scheme-handler/about" = [ "firefox.desktop" ];
        "x-scheme-handler/unknown" = [ "firefox.desktop" ];
        "x-scheme-handler/discord" = [ "vesktop.desktop" ];
      };
    };
  };

  programs = {
    home-manager.enable = true;
    firefox.enable = true;
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
          background = "0d0c0cfa"; # base00 with alpha
          text = "c5c9c5ff"; # base05
          border = "c4b28aff"; # base0A
          selection = "8ba4b0ff"; # base0D
          selection-text = "0d0c0cff"; # base00
        };
      };
    };
    mpv = {
      enable = true;
      config = {
        gpu-context = "wayland";
        hwdec = "auto-copy";
        hwdec-codecs = "all";
        hr-seek-framedrop = "no";
        profile = "gpu-hq";
        gpu-api = "vulkan";
        screenshot-format = "png";
        screenshot-high-bit-depth = "yes";
        screenshot-png-compression = "0";
        screenshot-directory = "~/Pictures/mpv/";
        screenshot-template = "%F - [%P] (%#01n)";
      };
    };
    brave = {
      enable = true;
      commandLineArgs = [
        "--enable-features=WebUIDarkMode"
        "--force-dark-mode"
      ];
      extensions = [
        { id = "akibfjgmcjogdlefokjmhblcibgkndog"; } # Shazam
        { id = "djnghjlejbfgnbnmjfgbdaeafbiklpha"; } # Kanagawa Theme
        { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
        { id = "mmioliijnhnoblpgimnlajmefafdfilb"; } # SponsorBlock
      ];
    };

    vscode = {
      enable = true;
      package = pkgs.vscode;
      profiles.default = {
        extensions =
          with pkgs.vscode-extensions;
          [
            bbenoist.nix
            ms-vscode-remote.remote-containers
            ms-vscode-remote.remote-ssh
            redhat.vscode-yaml
            kilocode.kilo-code
            mkhl.direnv
            qufiwefefwoyn.kanagawa
          ];
        userSettings = {
          "workbench.colorTheme" = "Kanagawa"; # TODO: Fix Missing Theme and Extension
          "editor.fontFamily" = "'Maple Mono', 'JetBrains Mono', monospace"; # TODO: Test/Verify Maple font is available
          "terminal.integrated.fontFamily" = "'Maple Mono', 'JetBrains Mono', monospace";
          "editor.fontSize" = 16;
          "editor.fontWeight" = "500";
          "editor.lineHeight" = 1.6;
          "editor.letterSpacing" = 1; 
          "terminal.integrated.fontSize" = 16;
          "terminal.integrated.lineHeight" = 1.5;
          "terminal.integrated.letterSpacing" = 1;
          "editor.fontLigatures" = false;
        };
      };
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qt5ct";
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
