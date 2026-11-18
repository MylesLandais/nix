_: {
  flake.modules.nixos.waydroidFeh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.fehWaydroid;
      androidPackage = "com.nintendo.zaba";

      fehWaydroid = pkgs.writeShellApplication {
        name = "feh-waydroid";
        runtimeInputs = with pkgs; [
          android-tools
          coreutils
          waydroid
          xdg-utils
        ];
        text =
          builtins.replaceStrings
            [
              "@NIX1@"
              "@NIX2@"
              "@NIX3@"
              "@NIX4@"
              "@NIX5@"
              "@NIX6@"
              "@NIX7@"
              "@NIX8@"
            ]
            [
              "${toString cfg.width}"
              "${toString cfg.height}"
              "${toString cfg.width}"
              "${toString cfg.height}"
              "${toString cfg.width}"
              "${toString cfg.height}"
              "${androidPackage}"
              "${androidPackage}"
            ]
            (builtins.readFile ./waydroid-feh/feh-waydroid.sh);
      };

      hostCheck = pkgs.writeShellApplication {
        name = "feh-waydroid-host-check";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          pciutils
          waydroid
        ];
        text = builtins.readFile ./waydroid-feh/feh-waydroid-host-check.sh;
      };

      bootstrap = pkgs.writeShellApplication {
        name = "feh-waydroid-bootstrap";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          waydroid
        ];
        text =
          builtins.replaceStrings [ "@NIX1@" "@NIX2@" ] [ "${toString cfg.width}" "${toString cfg.height}" ]
            (builtins.readFile ./waydroid-feh/feh-waydroid-bootstrap.sh);
      };

      armTranslation = pkgs.writeShellApplication {
        name = "feh-waydroid-arm-translation";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          git
          pciutils
          python3
          waydroid
        ];
        text = builtins.replaceStrings [ "@NIX1@" ] [ "${pkgs.python3}" ] (
          builtins.readFile ./waydroid-feh/feh-waydroid-arm-translation.sh
        );
      };

      deviceId = pkgs.writeShellApplication {
        name = "feh-waydroid-device-id";
        runtimeInputs = with pkgs; [
          coreutils
          waydroid
          xdg-utils
        ];
        text = builtins.readFile ./waydroid-feh/feh-waydroid-device-id.sh;
      };

      doctor = pkgs.writeShellApplication {
        name = "feh-waydroid-doctor";
        runtimeInputs = with pkgs; [
          android-tools
          coreutils
          gnugrep
          systemd
          waydroid
        ];
        text = builtins.replaceStrings [ "@NIX1@" "@NIX2@" ] [ "${androidPackage}" "${androidPackage}" ] (
          builtins.readFile ./waydroid-feh/feh-waydroid-doctor.sh
        );
      };

      gameplayTest = pkgs.writeShellApplication {
        name = "feh-waydroid-test";
        runtimeInputs = with pkgs; [
          coreutils
          gnugrep
          waydroid
        ];
        text = builtins.replaceStrings [ "@NIX1@" "@NIX2@" ] [ "${androidPackage}" "${androidPackage}" ] (
          builtins.readFile ./waydroid-feh/feh-waydroid-test.sh
        );
      };

      androidDevice = pkgs.writeShellApplication {
        name = "feh-android-device";
        runtimeInputs = with pkgs; [
          android-tools
          coreutils
          gnugrep
          usbutils
        ];
        text = builtins.replaceStrings [ "@NIX1@" ] [ "${androidPackage}" ] (
          builtins.readFile ./waydroid-feh/feh-android-device.sh
        );
      };

      samsungRecover = pkgs.writeShellApplication {
        name = "feh-samsung-recover";
        runtimeInputs = with pkgs; [
          android-tools
          coreutils
          scrcpy
        ];
        text = builtins.replaceStrings [ "@NIX1@" "@NIX2@" ] [ "${androidPackage}" "${androidPackage}" ] (
          builtins.readFile ./waydroid-feh/feh-samsung-recover.sh
        );
      };
    in
    {
      options.services.fehWaydroid = {
        enable = lib.mkEnableOption "Waydroid environment for Fire Emblem Heroes";
        user = lib.mkOption {
          type = lib.types.str;
          default = "warby";
        };
        width = lib.mkOption {
          type = lib.types.ints.positive;
          default = 720;
        };
        height = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1280;
        };
        useNftables = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };

      config = lib.mkIf cfg.enable {
        virtualisation.waydroid.enable = true;
        networking.nftables.enable = lib.mkIf cfg.useNftables true;
        environment.systemPackages = [
          pkgs.android-tools
          pkgs.scrcpy
          pkgs.usbutils
          pkgs.waydroid-helper
          fehWaydroid
          hostCheck
          bootstrap
          armTranslation
          deviceId
          doctor
          gameplayTest
          androidDevice
          samsungRecover
        ];

        environment.etc."waydroid/waydroid_base.prop".text = ''
          ro.hardware.gralloc=default
          ro.hardware.egl=swiftshader
          persist.waydroid.width=${toString cfg.width}
          persist.waydroid.height=${toString cfg.height}
          persist.waydroid.multi_windows=true
        '';

        environment.etc."xdg/applications/feh-waydroid.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Fire Emblem Heroes (Waydroid)
          Exec=feh-waydroid play
          Icon=applications-games
          Categories=Game;
          Terminal=false
        '';

        environment.etc."xdg/applications/waydroid-play-store.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Google Play (Waydroid)
          Exec=feh-waydroid store
          Icon=system-software-install
          Categories=System;
          Terminal=false
        '';
      };
    };
}
