{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.host.remoteGaming.enable {
    boot.kernelModules = [
      "uinput"
      "wireguard"
    ];

    services.sunshine = {
      enable = true;
      autoStart = true;
      openFirewall = true;
      capSysAdmin = true;
      package = pkgs.sunshine.override { cudaSupport = true; };

      # Global Sunshine settings (rendered to sunshine.conf)
      settings = {
        sunshine_name = "Cerberus Stream Host";
        min_log_level = "info";
        output_name = ""; # set to HEADLESS-1 after Phase 5 testing
      };

      # Declarative applications configuration (rendered to apps.json)
      # This makes the web UI read-only for app management
      applications = {
        # Global environment variables for all apps
        env = {
          PATH = "${pkgs.gamescope}/bin:${pkgs.steam}/bin:${
            pkgs.lib.makeBinPath [
              pkgs.coreutils
              pkgs.bash
            ]
          }";
        };

        apps = [
          # Steam Big Picture via Gamescope (iPad Mini native resolution)
          {
            name = "Steam Big Picture (iPad Mini)";
            cmd = "${pkgs.gamescope}/bin/gamescope -w 2266 -h 1488 -r 60 -f --rt --steam -- ${pkgs.steam}/bin/steam -bigpicture";
            "prep-cmd" = [
              {
                do = "";
                undo = "setsid sh -c 'pkill -f steam.*bigpicture || true'";
              }
            ];
            "auto-detach" = "true";
            "exclude-global-prep-cmd" = "false";
          }

          # Full desktop session via Gamescope (for non-Steam VNs)
          {
            name = "Full Desktop (iPad Mini)";
            cmd = "${pkgs.gamescope}/bin/gamescope -w 2266 -h 1488 -r 60 -f --rt -- ${pkgs.hyprland}/bin/Hyprland";
            "auto-detach" = "true";
            "exclude-global-prep-cmd" = "false";
          }

          # Fire Emblem: Path of Radiance via Dolphin
          {
            name = "Fire Emblem";
            cmd = "sunshine-stream ${pkgs.dolphin-emu}/bin/dolphin-emu \"/home/warby/Games/NGC/Fire Emblem - Path of Radiance (USA)/Fire Emblem - Path of Radiance (USA).nkit.iso\"";
            "prep-cmd" = [
              {
                do = "";
                undo = "setsid sh -c 'pkill -f dolphin-emu || true'";
              }
            ];
            "auto-detach" = "true";
            "exclude-global-prep-cmd" = "false";
          }
        ];
      };
    };

    # mDNS discovery for Moonlight clients
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    # TODO(unsolved): avahi-daemon will not restart in place. /run/avahi-daemon
    # persists across a stop owned by root, and avahi — which creates and chowns
    # that directory itself — then dies with "Failed to create runtime directory".
    # Before that it dies on the stale pid inside it ("Failed to create PID file:
    # File exists"). The practical effect is that the daemon survives only until
    # something restarts it; it had been up untouched since 2026-08-03 and failed
    # the moment a nixos-rebuild switch cycled it on 2026-08-09.
    # Neither RuntimeDirectory nor an ExecStartPre cleanup fixes it: the unit's
    # namespace hardening means a pre-start `rm` does not reach the real /run.
    # A reboot clears it (fresh /run tmpfs). To resolve properly, work out who
    # should own /run/avahi-daemon — likely a tmpfiles rule creating it as
    # avahi:avahi before the unit starts.

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "sunshine-stream" ''
        # Route audio to the Sunshine virtual sink
        export PULSE_SINK=sunshine_sink
        # Launch app inside gamescope with gamemode
        exec ${pkgs.gamescope}/bin/gamescope \
          -w 2160 -h 1440 -r 60 -f --rt \
          -- ${pkgs.gamemode}/bin/gamemoderun "$@"
      '')
    ];
  };
}
