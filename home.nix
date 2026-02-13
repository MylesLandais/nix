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
    stateVersion = "25.05"; # Please read the comment before changing.



    file = let
      waylandBrowserFlags = ''
        --ozone-platform-hint=wayland
        --enable-wayland-ime
      '';
    in {
      "${config.xdg.configHome}/ghostty/config".text = ''
        theme = "Kanagawa Dragon"
        background-opacity = 0.9
        window-decoration = false
        font-family = "'Maple Mono NF', JetBrainsMono Nerd Font"
        keybind = shift+enter=send_text:\n
      '';

      "${config.xdg.configHome}/electron-flags.conf".text = ''
        --ozone-platform=wayland
        --enable-features=WaylandWindowDecorations
      '';

      "${config.xdg.configHome}/chrome-flags.conf".text = waylandBrowserFlags;
      "${config.xdg.configHome}/chromium-flags.conf".text = waylandBrowserFlags;
      "${config.xdg.configHome}/vivaldi-flags.conf".text = waylandBrowserFlags;
      "${config.xdg.configHome}/thorium-flags.conf".text = waylandBrowserFlags;

      "${config.home.homeDirectory}/.local/share/nemo/actions/open-ghostty.nemo_action".text = ''
        [Nemo Action]
        Active=true
        Name=Open in Ghostty
        Comment=Open Ghostty terminal in the current directory
        Exec=${pkgs.ghostty}/bin/ghostty --working-directory=%F
        Icon-Name=com.mitchellh.ghostty
        Selection=any
        Extensions=dir;
        Quote=double
      '';

      # ".local/share/applications/open-stash-userscript.desktop".text = ''
      #   [Desktop Entry]
      #   Name=Install Stash Userscript
      #   Exec=chromium %u ~/.config/stash/open-media-player.user.js
      #   Type=Application
      #   Categories=Utility;
      # '';

      # "stash/open-media-player.user.js".source =
      #   let
      #     rawScript = builtins.fetchurl {
      #       url = "https://raw.githubusercontent.com/7dJx1qP/stash-userscripts/master/stash_open_media_player.user.js";
      #       sha256 = "sha256-PLACEHOLDER";
      #     };
      #     customizedScript = pkgs.runCommand "stash-open-media-player-custom.user.js" {} ''
      #       sed '
      #         s|// @match.*http://localhost:9999/*|// @match               http://localhost:9999/*|
      #         s|// @match.*https://localhost:9999/*|// @match              https://localhost:9999/*|
      #       ' ${rawScript} > $out
      #     '';
      #   in
      #     customizedScript;

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
      GDK_BACKEND = "wayland,x11";
      ANTHROPIC_API_KEY = "$ANTHROPIC_API_KEY";
      ZAI_API_KEY = "$(cat /run/agenix/zai-api-key)";
    };

    # Shell aliases for build-time sleep inhibition
    shellAliases = {
      nixos-rebuild-awake = "gnome-session-inhibit --inhibit idle sudo nixos-rebuild";
      nix-build-awake = "gnome-session-inhibit --inhibit idle nix build";
      npm = "bun";
    };


    packages = with pkgs; [
      # Additions for declarative archive handling in Nemo and CLI
      bind
      bitwarden-desktop
      btop
      coreutils
      devenv
      fastfetch
      fd
      ffmpeg
      file-roller # GNOME archive manager
      yt-dlp
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
      pkgs.ristretto # Image viewer
      shared-mime-info # MIME utilities
      webp-pixbuf-loader # WebP thumbnail support
      libheif
      heif-pixbuf-loader
      xdg-utils # XDG utilities
      nerd-fonts.droid-sans-mono
      maple-mono.truetype
      maple-mono.NF-unhinted
      # mpv # External media player - managed via programs.mpv
      nix-search-tv
       nixos-generators
       bun
       nwg-look
      obsidian
      opencloud-desktop
      inputs.opencode.packages.x86_64-linux.default
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
      python3
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
      inputs.cursor-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
      # Chromium-based browsers
      google-chrome
      vivaldi
      inputs.thorium.packages.${pkgs.stdenv.hostPlatform.system}.thorium-avx2
      # Firefox-based browser (stable Wayland/NVIDIA, uses DMABUF instead of Mailbox)
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      # Agentic IDE with Chrome integration
      inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.default
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
        "image/png" = [ "ristretto.desktop" ];
        "image/jpeg" = [ "ristretto.desktop" ];
        "image/gif" = [ "ristretto.desktop" ];
        "image/webp" = [ "ristretto.desktop" ];
        "image/avif" = [ "ristretto.desktop" ];
        "image/heic" = [ "ristretto.desktop" ];
        "image/bmp" = [ "ristretto.desktop" ];
        "image/tiff" = [ "ristretto.desktop" ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/mpeg" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];
        "application/ogg" = [ "mpv.desktop" ];
      };
    };
  };

   programs = {
    chromium = {
      enable = true;
      extensions = [
        # { id = "dhdgffkkebhmkhlelgalapkzlidofg"; } # Tampermonkey - TODO: fix ID validation issue
      ];
    };
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
        hr-seek = "yes";
        seek = "exact";
      };
      extraInput = ''
        , frame-step ; show-text "Frame forward"
        . frame-back-step ; show-text "Frame backward"
        [ ignore ; frame-back-step ; set time-pos ''${time-pos}; set ab-loop-a ''${time-pos}; show-text "A set at ''${time-pos}"
        ] ignore ; frame-step ; set time-pos ''${time-pos}; set ab-loop-b ''${time-pos}; show-text "B set at ''${time-pos}"
        l set ab-loop-a no; set ab-loop-b no; show-text "A-B loop cleared"
      '';
      scripts = with pkgs.mpvScripts; [ uosc ];
    };
    # mpv: Frame-accurate A-B looping with uosc for precise video analysis

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
            rooveterinaryinc.roo-cline
            mkhl.direnv
          ];
        userSettings = {
          #"workbench.colorTheme" = "Kanagawa"; # TODO: Fix Missing Theme and Extension
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

  # GTK dark mode preferences (theme managed by Stylix)
  gtk = {
    enable = true;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
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

  dconf.settings = {
    # Dark mode signal for portals (Firefox, Chrome, GTK4 apps)
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
    "org/nemo/preferences" = {
      show-image-thumbnails = "always";
      thumbnail-limit = lib.hm.gvariant.mkUint64 2147483648; # 2 GB
      "context-menus-show-open-in-terminal" = true;
    };
    "org/cinnamon/desktop/default-applications/terminal" = {
      exec = "${pkgs.ghostty}/bin/ghostty";
      exec-arg = "--working-directory";
    };
  };
}
