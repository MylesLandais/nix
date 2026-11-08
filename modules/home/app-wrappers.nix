# Safe launch wrappers for Electron apps on Wayland / NVIDIA (Vesktop, Cursor).
_: {
  flake.modules.homeManager.appWrappers =
    {
      config,
      lib,
      pkgs,
      osConfig,
      ...
    }:
    let
      gpuType = osConfig.host.gpuType or "none";

      cfg = config.appWrappers;

      vesktopSafe = pkgs.writeShellApplication {
        name = "vesktop";
        runtimeInputs = [ pkgs.vesktop ];
        text = ''
          exec ${lib.getExe pkgs.vesktop} \
            --disable-gpu-sandbox \
            --ozone-platform-hint=auto \
            "$@"
        '';
      };

      # TODO(deprecated): Cursor is tagged for removal (2026-11-06). Drop cursorSafe,
      # the two cursor desktop entries, the icon and argv.json below, but keep the
      # module (Vesktop uses it). Then remove ~/.config/Cursor (~14 GB, mostly the
      # 9 GB chat-history state.vscdb).
      cursorSafe = pkgs.writeShellApplication {
        name = "cursor";
        runtimeInputs = [ pkgs.code-cursor ];
        text =
          if gpuType == "nvidia" then
            ''
              # Native Wayland + NVIDIA: desktop GL instead of Vulkan ANGLE under agent load.
              export __GLX_VENDOR_LIBRARY_NAME=nvidia
              export GBM_BACKEND=nvidia-drm
              export LIBVA_DRIVER_NAME=nvidia
              export GDK_BACKEND=wayland

              exec ${pkgs.code-cursor}/bin/cursor \
                --ozone-platform=wayland \
                --enable-features=UseOzonePlatform,WaylandWindowDecorations \
                --use-angle=gl \
                --enable-wayland-ime \
                --js-flags=--max-old-space-size=8192 \
                "$@"
            ''
          else
            ''
              exec ${pkgs.code-cursor}/bin/cursor \
                --ozone-platform-hint=auto \
                "$@"
            '';
      };
    in
    {
      options.appWrappers = {
        enable = lib.mkEnableOption "Vesktop and Cursor safe launch wrappers with desktop entries";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [
          (lib.hiPrio vesktopSafe)
          (lib.hiPrio cursorSafe)
        ];

        xdg.desktopEntries.vesktop = {
          name = "Vesktop";
          genericName = "Internet Messenger";
          exec = "${vesktopSafe}/bin/vesktop %U";
          icon = "vesktop";
          terminal = false;
          categories = [
            "Network"
            "InstantMessaging"
            "Chat"
          ];
          mimeType = [ "x-scheme-handler/discord" ];
        };

        xdg.desktopEntries.cursor = {
          name = "Cursor";
          genericName = "Text Editor";
          exec = "${cursorSafe}/bin/cursor %F";
          icon = "cursor";
          terminal = false;
          categories = [
            "Utility"
            "TextEditor"
            "Development"
            "IDE"
          ];
          mimeType = [ "application/x-cursor-workspace" ];
        };

        xdg.desktopEntries.cursor-url-handler = {
          name = "Cursor - URL Handler";
          exec = "${cursorSafe}/bin/cursor --open-url %U";
          icon = "cursor";
          terminal = false;
          noDisplay = true;
          mimeType = [ "x-scheme-handler/cursor" ];
        };

        # Only the wrapper is installed, not code-cursor itself, so its icon never
        # reaches a profile and Icon=cursor resolved to nothing.
        xdg.dataFile."icons/hicolor/256x256/apps/cursor.png".source =
          "${pkgs.code-cursor}/share/pixmaps/cursor.png";

        home.file."${config.xdg.configHome}/Cursor/argv.json".text = builtins.toJSON {
          disable-hardware-acceleration = false;
        };
      };
    };
}
