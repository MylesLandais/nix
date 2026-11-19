{ inputs, ... }:
{
  flake.modules.homeManager.bars =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.my.bars.noctalia.enable = lib.mkEnableOption "the Noctalia desktop shell";

      config = lib.mkIf config.my.bars.noctalia.enable {
        programs.noctalia = {
          enable = true;
          systemd.enable = true;
          settings = {
            shell = {
              font_family = "Maple Mono NF";
              avatar_path = "${config.home.homeDirectory}/.face";
              setup_wizard_enabled = false;
              launch_apps_custom_command = "${lib.getExe pkgs.app2unit} -- $CMD";
              clipboard_enabled = true;
              clipboard_history_max_entries = 750;
              clipboard_auto_paste = "off";
              launcher.auto_paste = "off";
            };
            bar.main = {
              position = "top";
              background_opacity = 0.0;
              capsule = true;
              margin_ends = 1;
              margin_edge = 0;
              start = [
                "launcher"
                "clock"
              ];
              center = [ "workspaces" ];
              end = [
                "tray"
                "notes"
                "control-center"
              ];
            };
            widget.notes.type = "noctalia/notes:notes";
            plugins.enabled = [ "noctalia/notes" ];
            theme = {
              mode = "dark";
              source = "wallpaper";
              wallpaper_scheme = "m3-fruit-salad";
            };
            wallpaper = {
              directory = toString inputs.wallpapers;
              fill_mode = "crop";
              automation.recursive = true;
            };
            notification = {
              monitors = [ "DP-3" ];
              position = "top_right";
              layer = "overlay";
              background_opacity = 1.0;
            };
            nightlight = {
              enabled = false;
              temperature_day = 6500;
              temperature_night = 4000;
            };
            lockscreen.lock_before_suspend = true;
            location.address = "Madrid";
            storage = {
              key_source = "file";
              key_file = "${config.xdg.stateHome}/noctalia/storage.key";
            };
          };
        };

        # The login keyring can stay locked on an autologin desktop. Generate a
        # private, persistent key before the shell starts, outside the Nix store.
        home.activation.noctaliaStorageKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${pkgs.bash}/bin/bash -euc '
            umask 077
            dir=$1
            mkdir -p "$dir"
            if [[ ! -e "$dir/storage.key" ]]; then
              tmp=$(mktemp "$dir/.storage-key.XXXXXXXX")
              trap "rm -f -- \"\$tmp\"" EXIT
              ${pkgs.openssl}/bin/openssl rand -hex 32 > "$tmp"
              ln -T "$tmp" "$dir/storage.key" || test -f "$dir/storage.key"
            fi
          ' _ "${config.xdg.stateHome}/noctalia"
        '';
      };
    };
}
