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
          preferences = {
            "accessibility" = { "captions" = { "headless_caption_enabled" = false; }; };
            "alternate_error_pages" = { "backup" = false; };
            "announcement_notification_service_first_run_time" = "13404068394559929";
            "apps" = { "shortcuts_arch" = ""; "shortcuts_version" = 0; };
            "autocomplete" = { "retention_policy_last_version" = 140; };
            "autofill" = { "last_version_deduped" = 140; };
            "bookmark" = { "storage_computation_last_update" = "13404068394864321"; };
            "brave" = {
              "accelerators" = {
                "33000" = [ "BrowserBack" "Alt+ArrowLeft" "AltGr+ArrowLeft" ];
                "33001" = [ "BrowserForward" "Alt+ArrowRight" "AltGr+ArrowRight" ];
                "33002" = [ "Control+KeyR" "F5" "BrowserRefresh" ];
                "33003" = [ "BrowserHome" "Alt+Home" ];
                "33007" = [ "Control+Shift+KeyR" "Control+F5" "Shift+F5" "Control+BrowserRefresh" "Shift+BrowserRefresh" ];
                "34000" = [ "Control+KeyN" ];
                "34001" = [ "Control+Shift+KeyN" ];
                "34012" = [ "Control+Shift+KeyW" "Alt+F4" ];
                "34014" = [ "AppNew" "Control+KeyT" ];
                "34015" = [ "Control+KeyW" "Control+F4" "AppClose" ];
                "34016" = [ "Control+Tab" "Control+PageDown" ];
                "34017" = [ "Control+Shift+Tab" "Control+PageUp" ];
                "34018" = [ "Control+Digit1" "Control+Numpad1" "Alt+Digit1" "Alt+Numpad1" ];
                "34019" = [ "Control+Digit2" "Control+Numpad2" "Alt+Digit2" "Alt+Numpad2" ];
                "34020" = [ "Control+Digit3" "Control+Numpad3" "Alt+Digit3" "Alt+Numpad3" ];
                "34021" = [ "Control+Digit4" "Control+Numpad4" "Alt+Digit4" "Alt+Numpad4" ];
                "34022" = [ "Control+Digit5" "Control+Numpad5" "Alt+Digit5" "Alt+Numpad5" ];
                "34023" = [ "Control+Digit6" "Control+Numpad6" "Alt+Digit6" "Alt+Numpad6" ];
                "34024" = [ "Control+Digit7" "Control+Numpad7" "Alt+Digit7" "Alt+Numpad7" ];
                "34025" = [ "Control+Digit8" "Control+Numpad8" "Alt+Digit8" "Alt+Numpad8" ];
                "34026" = [ "Control+Digit9" "Control+Numpad9" "Alt+Digit9" "Alt+Numpad9" ];
                "34028" = [ "Control+Shift+KeyT" ];
                "34030" = [ "F11" ];
                "34032" = [ "Control+Shift+PageDown" ];
                "34033" = [ "Control+Shift+PageUp" ];
                "34100" = [ "Alt+Shift+KeyC" ];
                "34101" = [ "Alt+Shift+KeyP" ];
                "34102" = [ "Alt+Shift+KeyX" ];
                "34103" = [ "Alt+Shift+KeyZ" ];
                "34104" = [ "Alt+Shift+KeyW" ];
                "35000" = [ "Control+KeyD" ];
                "35001" = [ "Control+Shift+KeyD" ];
                "35002" = [ "Control+KeyU" ];
                "35003" = [ "Control+KeyP" ];
                "35004" = [ "Control+KeyS" ];
                "35007" = [ "Control+Shift+KeyP" ];
                "35031" = [ "Control+Shift+KeyS" ];
                "37000" = [ "Control+KeyF" ];
                "37001" = [ "Control+KeyG" "F3" ];
                "37002" = [ "Control+Shift+KeyG" "Shift+F3" ];
                "37003" = [ "Escape" ];
                "38001" = [ "Control+Equal" "Control+NumpadAdd" "Control+Shift+Equal" ];
                "38002" = [ "Control+Digit0" "Control+Numpad0" ];
                "38003" = [ "Control+Minus" "Control+NumpadSubtract" "Control+Shift+Minus" ];
                "39000" = [ "Alt+Shift+KeyT" ];
                "39001" = [ "Control+KeyL" "Alt+KeyD" ];
                "39002" = [ "BrowserSearch" "Control+KeyE" "Control+KeyK" ];
                "39003" = [ "F10" "AltGr" "Alt" ];
                "39004" = [ "F6" ];
                "39005" = [ "Shift+F6" ];
                "39006" = [ "Alt+Shift+KeyB" ];
                "39007" = [ "Alt+Shift+KeyA" ];
                "39009" = [ "Control+F6" ];
                "40000" = [ "Control+KeyO" ];
                "40004" = [ "Control+Shift+KeyI" ];
                "40005" = [ "Control+Shift+KeyJ" ];
                "40009" = [ "BrowserFavorites" "Control+Shift+KeyB" ];
                "40010" = [ "Control+KeyH" ];
                "40011" = [ "Control+Shift+KeyO" ];
                "40012" = [ "Control+KeyJ" ];
                "40013" = [ "Control+Shift+Delete" ];
                "40019" = [ "F1" ];
                "40021" = [ "Alt+KeyE" "Alt+KeyF" ];
                "40023" = [ "Control+Shift+KeyC" ];
                "40134" = [ "Control+Shift+KeyM" ];
                "40237" = [ "F12" ];
                "40260" = [ "F7" ];
                "40286" = [ "Shift+Escape" ];
                "52500" = [ "Control+Shift+KeyA" ];
                "56003" = [ "Alt+Shift+KeyN" ];
                "56041" = [ "Control+KeyM" ];
                "56044" = [ "Control+KeyB" ];
                "56301" = [ "Control+Space" ];
              };
              "brave_ads" = {
                "notification_ads" = [ ];
                "should_allow_ads_subdivision_targeting" = false;
                "state" = {
                  "has_migrated" = {
                    "client" = { "v7" = true; };
                    "confirmations" = { "v8" = true; };
                    "v2" = true;
                  };
                };
              };
              "brave_dark_mode" = true;
              "brave_search" = { "last-used-ntp-search-engine" = "search.brave.com"; };
              "default_accelerators" = {
                "33000" = [ "BrowserBack" "Alt+ArrowLeft" "AltGr+ArrowLeft" ];
                "33001" = [ "BrowserForward" "Alt+ArrowRight" "AltGr+ArrowRight" ];
                "33002" = [ "Control+KeyR" "F5" "BrowserRefresh" ];
                "33003" = [ "BrowserHome" "Alt+Home" ];
                "33007" = [ "Control+Shift+KeyR" "Control+F5" "Shift+F5" "Control+BrowserRefresh" "Shift+BrowserRefresh" ];
                "34000" = [ "Control+KeyN" ];
                "34001" = [ "Control+Shift+KeyN" ];
                "34012" = [ "Control+Shift+KeyW" "Alt+F4" ];
                "34014" = [ "AppNew" "Control+KeyT" ];
                "34015" = [ "Control+KeyW" "Control+F4" "AppClose" ];
                "34016" = [ "Control+Tab" "Control+PageDown" ];
                "34017" = [ "Control+Shift+Tab" "Control+PageUp" ];
                "34018" = [ "Control+Digit1" "Control+Numpad1" "Alt+Digit1" "Alt+Numpad1" ];
                "34019" = [ "Control+Digit2" "Control+Numpad2" "Alt+Digit2" "Alt+Numpad2" ];
                "34020" = [ "Control+Digit3" "Control+Numpad3" "Alt+Digit3" "Alt+Numpad3" ];
                "34021" = [ "Control+Digit4" "Control+Numpad4" "Alt+Digit4" "Alt+Numpad4" ];
                "34022" = [ "Control+Digit5" "Control+Numpad5" "Alt+Digit5" "Alt+Numpad5" ];
                "34023" = [ "Control+Digit6" "Control+Numpad6" "Alt+Digit6" "Alt+Numpad6" ];
                "34024" = [ "Control+Digit7" "Control+Numpad7" "Alt+Digit7" "Alt+Numpad7" ];
                "34025" = [ "Control+Digit8" "Control+Numpad8" "Alt+Digit8" "Alt+Numpad8" ];
                "34026" = [ "Control+Digit9" "Control+Numpad9" "Alt+Digit9" "Alt+Numpad9" ];
                "34028" = [ "Control+Shift+KeyT" ];
                "34030" = [ "F11" ];
                "34032" = [ "Control+Shift+PageDown" ];
                "34033" = [ "Control+Shift+PageUp" ];
                "34100" = [ "Alt+Shift+KeyC" ];
                "34101" = [ "Alt+Shift+KeyP" ];
                "34102" = [ "Alt+Shift+KeyX" ];
                "34103" = [ "Alt+Shift+KeyZ" ];
                "34104" = [ "Alt+Shift+KeyW" ];
                "35000" = [ "Control+KeyD" ];
                "35001" = [ "Control+Shift+KeyD" ];
                "35002" = [ "Control+KeyU" ];
                "35003" = [ "Control+KeyP" ];
                "35004" = [ "Control+KeyS" ];
                "35007" = [ "Control+Shift+KeyP" ];
                "35031" = [ "Control+Shift+KeyS" ];
                "37000" = [ "Control+KeyF" ];
                "37001" = [ "Control+KeyG" "F3" ];
                "37002" = [ "Control+Shift+KeyG" "Shift+F3" ];
                "37003" = [ "Escape" ];
                "38001" = [ "Control+Equal" "Control+NumpadAdd" "Control+Shift+Equal" ];
                "38002" = [ "Control+Digit0" "Control+Numpad0" ];
                "38003" = [ "Control+Minus" "Control+NumpadSubtract" "Control+Shift+Minus" ];
                "39000" = [ "Alt+Shift+KeyT" ];
                "39001" = [ "Control+KeyL" "Alt+KeyD" ];
                "39002" = [ "BrowserSearch" "Control+KeyE" "Control+KeyK" ];
                "39003" = [ "F10" "Alt" "Alt" "AltGr" ];
                "39004" = [ "F6" ];
                "39005" = [ "Shift+F6" ];
                "39006" = [ "Alt+Shift+KeyB" ];
                "39007" = [ "Alt+Shift+KeyA" ];
                "39009" = [ "Control+F6" ];
                "40000" = [ "Control+KeyO" ];
                "40004" = [ "Control+Shift+KeyI" ];
                "40005" = [ "Control+Shift+KeyJ" ];
                "40009" = [ "BrowserFavorites" "Control+Shift+KeyB" ];
                "40010" = [ "Control+KeyH" ];
                "40011" = [ "Control+Shift+KeyO" ];
                "40012" = [ "Control+KeyJ" ];
                "40013" = [ "Control+Shift+Delete" ];
                "40019" = [ "F1" ];
                "40021" = [ "Alt+KeyE" "Alt+KeyF" ];
                "40023" = [ "Control+Shift+KeyC" ];
                "40134" = [ "Control+Shift+KeyM" ];
                "40237" = [ "F12" ];
                "40260" = [ "F7" ];
                "40286" = [ "Shift+Escape" ];
                "52500" = [ "Control+Shift+KeyA" ];
                "56003" = [ "Alt+Shift+KeyN" ];
                "56041" = [ "Control+KeyM" ];
                "56044" = [ "Control+KeyB" ];
                "56301" = [ "Control+Space" ];
              };
              "default_private_search_provider_data" = {
                "alternate_urls" = [ ];
                "contextual_search_url" = "";
                "created_from_play_api" = false;
                "date_created" = "0";
                "doodle_url" = "";
                "enforced_by_policy" = false;
                "favicon_url" = "https://cdn.search.brave.com/serp/favicon.ico";
                "featured_by_policy" = false;
                "id" = "0";
                "image_search_branding_label" = "";
                "image_translate_source_language_param_key" = "";
                "image_translate_target_language_param_key" = "";
                "image_translate_url" = "";
                "image_url" = "";
                "image_url_post_params" = "";
                "input_encodings" = [ "UTF-8" ];
                "is_active" = 0;
                "keyword" = ":br";
                "last_modified" = "0";
                "last_visited" = "0";
                "logo_url" = "";
                "new_tab_url" = "";
                "originating_url" = "";
                "policy_origin" = 0;
                "preconnect_to_search_url" = false;
                "prefetch_likely_navigations" = false;
                "prepopulate_id" = 550;
                "safe_for_autoreplace" = true;
                "search_intent_params" = [ ];
                "search_url_post_params" = "";
                "short_name" = "Brave";
                "starter_pack_id" = 0;
                "suggestions_url" = "https://search.brave.com/api/suggest?q={searchTerms}&rich=true&source=desktop";
                "suggestions_url_post_params" = "";
                "synced_guid" = "485bf7d3-0215-45af-87dc-538868000550";
                "url" = "https://search.brave.com/search?q={searchTerms}&source=desktop";
                "usage_count" = 0;
              };
              "default_private_search_provider_guid" = "485bf7d3-0215-45af-87dc-538868000550";
              "enable_media_router_on_restart" = true;
              "enable_window_closing_confirm" = true;
              "has_seen_brave_welcome_page" = true;
              "migrated_search_default_in_jp" = true;
              "rewards" = {
                "enabled" = false;
                "notifications" = "{\"displayed\":[],\"notifications\":[]}";
                "scheduled_captcha" = { "failed_attempts" = 0; "id" = ""; "paused" = false; "payment_id" = ""; };
                "show_brave_rewards_button" = false;
              };
              "search" = { "default_version" = 32; };
              "shields_settings_version" = 4;
              "stats" = {
                "ads_blocked" = "85";
                "bandwidth_saved_bytes" = "3112716";
                "daily_saving_predictions_bytes" = [ { "day" = 1759550400.0; "value" = 3112716.0; } ];
              };
              "tabs" = { "vertical_tabs_enabled" = true; };
              "today" = {
                "p3a_total_card_views" = [ { "day" = 1759550400.0; "value" = 0.0; } ];
                "p3a_total_card_visits" = [ { "day" = 1759550400.0; "value" = 0.0; } ];
                "p3a_total_sidebar_filter_usages" = [ { "day" = 1759550400.0; "value" = 0.0; } ];
              };
              "vertical_tabs" = { "enabled" = true; "position" = "left"; };
              "wallet" = {
                "aurora_mainnet_migrated" = true;
                "custom_networks" = { "goerli_migrated" = true; };
                "eip1559_chains_migrated" = true;
                "is_compressed_nft_migrated" = true;
                "is_spl_token_program_migrated" = true;
                "keyrings" = { };
                "last_transaction_sent_time_dict" = { };
              };
              "web_discovery" = { "cta_state" = { "count" = 1; "dismissed" = false; "id" = "v1"; "last_displayed" = "13404069910552453"; }; };
              "weekly_storage" = { "search_count" = [ { "day" = 1759550400.0; "value" = 2.0; } ]; };
            };
          };
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
