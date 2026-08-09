{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mpv-mod;
  plexShimPackage = pkgs.plex-mpv-shim.override {
    python3Packages = pkgs.python3Packages.overrideScope (
      _: pyPrev: {
        # The upstream python-mpv concurrency test consistently fails in the
        # sandbox even though the remaining test suite and import check pass.
        mpv = pyPrev.mpv.overridePythonAttrs (_: {
          doCheck = false;
        });
      }
    );
  };
  plexShimConfig = {
    player_name = "Cerberus MPV";
    always_transcode = false;
    auto_transcode = false;
    direct_limit = false;
    fullscreen = true;
    enable_gui = true;
    enable_osc = false;
    sanitize_output = true;
    mpv_ext = true;
    mpv_ext_path = "${config.programs.mpv.package}/bin/mpv";
    mpv_ext_start = true;
    mpv_ext_no_ovr = true;
  };
  plexShimLauncher = pkgs.writeShellApplication {
    name = "plex-mpv-shim-managed";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      plexShimPackage
    ];
    text = ''
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/plex-mpv-shim"
      config_file="$config_dir/conf.json"
      config_tmp="$config_file.tmp"
      managed_config=${lib.escapeShellArg (builtins.toJSON plexShimConfig)}

      mkdir -p "$config_dir"
      if [[ -e "$config_file" ]]; then
        if ! jq empty "$config_file" >/dev/null 2>&1; then
          echo "plex-mpv-shim: refusing to overwrite malformed $config_file" >&2
          exit 1
        fi
        jq --argjson managed "$managed_config" '. * $managed' "$config_file" > "$config_tmp"
      else
        printf '%s\n' "$managed_config" > "$config_tmp"
      fi

      chmod 600 "$config_tmp"
      mv "$config_tmp" "$config_file"
      exec env LC_NUMERIC=C plex-mpv-shim --config "$config_dir"
    '';
  };

  # Stock OSC cousin of IINA/Tint control language (ASS alpha, not real glass).
  # Docs: [[iina-aesthetics-on-mpv-osc]] · vault cookbook §11.
  # Cerberus ships mpv 0.41 — no `layout=floating` yet (added post-0.41, Mar 2026).
  # Use centered `box` + boxalpha/valign as the floating-pill cousin until upgrade.
  iinaOscScriptOpts = {
    layout = "box";
    boxalpha = 105;
    valign = 0.8;
    halign = 0.0;
    seekbarstyle = "knob";
    seekbarhandlesize = 0.45;
    hidetimeout = 2500;
    fadeduration = 250;
    fadein = "yes";
    background_color = "#111111";
    timecode_color = "#B3B3B3";
    title_color = "#B3B3B3";
    buttons_color = "#CCCCCC";
    small_buttonsL_color = "#999999";
    small_buttonsR_color = "#999999";
    top_buttons_color = "#B3B3B3";
    held_element_color = "#666666";
    time_pos_color = "#E0E0E0";
    deadzonesize = 0.0;
  };

  useReplacementOsc = cfg.modernx.enable || cfg.uosc.enable;
in
{
  options.mpv-mod = {
    enable = lib.mkEnableOption "shared MPV configuration";

    modernx.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the ModernX MPV OSC replacement (disables stock OSC).";
    };

    uosc.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the uosc MPV OSC replacement.";
    };

    iinaOscTheme.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        IINA/Tint-inspired stock OSC via script-opts (floating greyscale, 2.5s hide).
        Requires stock OSC (modernx and uosc off). On mpv 0.41 uses layout=box;
        switch to layout=floating after upgrading past 0.41. Does not set stylix osd-* keys.
      '';
    };

    plexShim.enable = lib.mkEnableOption "Plex MPV Shim cast target";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !(cfg.modernx.enable && cfg.uosc.enable);
            message = "mpv-mod.modernx.enable and mpv-mod.uosc.enable are mutually exclusive";
          }
          {
            assertion = !(cfg.iinaOscTheme.enable && useReplacementOsc);
            message = "mpv-mod.iinaOscTheme.enable requires stock OSC; disable modernx and uosc";
          }
        ];

        programs.mpv = {
          enable = true;
          config = {
            # Optional interfaces replace mpv's built-in OSC.
            osc = if useReplacementOsc then "no" else "yes";
            vo = "gpu-next";
            gpu-context = "wayland";
            hwdec = "auto-safe";
            hwdec-codecs = "all";
            hr-seek-framedrop = "no";
            profile = "gpu-hq";
            # Vulkan fails to initialize reliably on Cerberus. Keep the verified
            # gpu-next + OpenGL + Wayland path shared by the workstation hosts.
            gpu-api = "opengl";
            screenshot-format = "png";
            screenshot-high-bit-depth = "yes";
            screenshot-png-compression = "0";
            screenshot-directory = "~/Pictures/mpv/";
            screenshot-template = "%F - [%P] (%#01n)";
            hr-seek = "yes";
          };
          extraInput = ''
            , frame-step ; show-text "Frame forward"
            . frame-back-step ; show-text "Frame backward"
            [ ignore ; frame-back-step ; set time-pos ''${time-pos}; set ab-loop-a ''${time-pos}; show-text "A set at ''${time-pos}"
            ] ignore ; frame-step ; set time-pos ''${time-pos}; set ab-loop-b ''${time-pos}; show-text "B set at ''${time-pos}"
            l set ab-loop-a no; set ab-loop-b no; show-text "A-B loop cleared"
          '';
          scripts =
            lib.optionals cfg.modernx.enable [ pkgs.mpvScripts.modernx ]
            ++ lib.optionals cfg.uosc.enable [ pkgs.mpvScripts.uosc ];
          scriptOpts = lib.mkIf cfg.iinaOscTheme.enable {
            osc = iinaOscScriptOpts;
          };
        };

      }

      (lib.mkIf cfg.plexShim.enable {
        home.packages = [ plexShimPackage ];

        systemd.user.services.plex-mpv-shim = {
          Unit = {
            Description = "Plex MPV Shim cast target";
            After = [
              "graphical-session.target"
              "hyprland-session.target"
            ];
            PartOf = [ "graphical-session.target" ];
            Wants = [ "hyprland-session.target" ];
            StartLimitIntervalSec = 300;
            StartLimitBurst = 5;
          };
          Service = {
            ExecStart = "${plexShimLauncher}/bin/plex-mpv-shim-managed";
            Restart = "on-failure";
            RestartSec = "3s";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })
    ]
  );
}
