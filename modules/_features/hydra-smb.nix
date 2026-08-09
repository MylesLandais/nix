# Hydra (Unraid) SMB for Nemo on Hyprland.
#
# Stable layout (pre-2e9e10b): Hydra + mount-hydra lived in hypr.nix with gcr on the
# user dbus, Nemo in home.nix, and credentials in gnome-keyring from the Nemo UI.
# Dendritic refactor (2e9e10b) stopped importing that monolithic hypr.nix for cerberus;
# this module restores the GVfs mount path in the new modules/home.nix layout.
#
# authMode "keyring" (default): gio mount smb://hydra/data using saved gnome-keyring
# entries from Nemo → Connect to Server (your previous workflow).
#
# authMode "public": guest URIs for Unraid SMB Security: Public only. Use if keyring
# has stale root@hydra entries that break anonymous access.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.hydra-smb;

  uid =
    if config.home.uid != null then
      config.home.uid
    else
      lib.attrByPath [ "users" "users" config.home.username "uid" ] 1000 osConfig;
  runtimeDir = "/run/user/${toString uid}";
  gvfsDir = "${runtimeDir}/gvfs/smb-share:server=${cfg.serverName},share=${cfg.share}";

  mountUri =
    if cfg.smbUser != "" then
      "smb://${cfg.smbUser}@${cfg.serverName}/${cfg.share}"
    else
      "smb://${cfg.serverName}/${cfg.share}";

  publicUris = [
    mountUri
    "smb://guest@${cfg.serverName}/${cfg.share}"
  ];

  gio = "${pkgs.glib}/bin/gio";

  gioMount =
    if cfg.authMode == "public" then
      "${gio} mount smb://guest@${cfg.serverName}/${cfg.share}"
    else
      "${gio} mount ${mountUri}";

  mountScript = pkgs.writeShellScriptBin "mount-hydra-gvfs" ''
    set -euo pipefail

    runtime="''${XDG_RUNTIME_DIR:-${runtimeDir}}"
    export XDG_RUNTIME_DIR="$runtime"
    export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime/bus}"

    gvfs_path="$runtime/gvfs/smb-share:server=${cfg.serverName},share=${cfg.share}"
    shortcut="${config.home.homeDirectory}/Hydra"
    auth_mode="${cfg.authMode}"

    if [ -d "$gvfs_path" ]; then
      ln -sfn "$gvfs_path" "$shortcut"
      echo "Hydra GVfs mount already present: $gvfs_path"
      exit 0
    fi

    try_mount() {
      local uri="$1"
      echo "Trying: $uri"
      ${gio} mount "$uri"
    }

    mounted=0
    if [ "$auth_mode" = "public" ]; then
      for uri in ${lib.concatStringsSep " " (map (u: "\"${u}\"") publicUris)}; do
        if try_mount "$uri" && [ -d "$gvfs_path" ]; then
          mounted=1
          break
        fi
        ${gio} mount -u "$uri" 2>/dev/null || true
      done
    else
      if try_mount "${mountUri}" && [ -d "$gvfs_path" ]; then
        mounted=1
      fi
    fi

    if [ "$mounted" -ne 1 ]; then
      echo "gio mount failed (authMode=$auth_mode)." >&2
      echo "Connect once in Nemo → smb://${cfg.serverName}/${cfg.share} and save to keyring." >&2
      if [ "$auth_mode" = "public" ]; then
        echo "Or clear stale entries: hydra-smb-clear-keyring" >&2
      fi
      rm -f "$shortcut"
      exit 1
    fi

    ln -sfn "$gvfs_path" "$shortcut"
    echo "Hydra mounted at $shortcut -> $gvfs_path"
  '';

  resetCredsScript = pkgs.writeShellScriptBin "hydra-smb-clear-keyring" ''
    set -euo pipefail
    echo "Stored Samba/GVfs credentials:"
    ${lib.getExe pkgs.libsecret}/bin/secret-tool search service samba 2>/dev/null || true
    ${lib.getExe pkgs.libsecret}/bin/secret-tool search protocol smb 2>/dev/null || true
    echo ""
    echo "To remove: secret-tool clear service samba server ${cfg.serverName} user USERNAME"
  '';
in
{
  options.hydra-smb = {
    enable = lib.mkEnableOption "GVfs SMB mount and ~/Hydra shortcut for the Hydra (Unraid) share";

    address = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.222";
      description = "Hydra LAN address.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "hydra";
      description = "Host name in smb:// URIs and GVfs mount directory name.";
    };

    share = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "SMB export name on Hydra (Unraid share name).";
    };

    authMode = lib.mkOption {
      type = lib.types.enum [
        "keyring"
        "public"
      ];
      default = "keyring";
      description = ''
        keyring: use gnome-keyring credentials from Nemo (previous stable workflow).
        public: anonymous guest mount for Unraid SMB Security: Public.
      '';
    };

    smbUser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Optional smb://USER@host when authMode is keyring.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      samba
      cifs-utils
      mountScript
      resetCredsScript
    ];

    home.file = {
      "Hydra".source = config.lib.file.mkOutOfStoreSymlink gvfsDir;
      ".smb/smb.conf".text = ''
        [global]
          client min protocol = SMB2
          client max protocol = SMB3
          map to guest = Bad User
      '';
    };

    dconf.settings."org/gnome/system/smb" = {
      workgroup = "WORKGROUP";
    };

    systemd.user.services.mount-hydra = {
      Unit = {
        Description = "Mount Hydra SMB share (${cfg.share}) via GVfs for Nemo";
        # SMB mount is best-effort; do not block home-manager activation on it.
        X-SwitchMethod = "keep-old";
        After = [
          "gvfs-daemon.service"
          "gnome-keyring.service"
          "graphical-session.target"
          "hyprland-session.target"
          "network-online.target"
        ];
        Wants = [
          "gvfs-daemon.service"
          "gnome-keyring.service"
          "network-online.target"
        ];
        # TODO(unsolved): retried 3900 times. The mount is declared best-effort, but
        # nothing capped the retries, so a share that is simply unavailable becomes a
        # permanent 30s-interval loop. Failing after 5 attempts keeps it best-effort
        # without the loop; a genuinely absent Hydra is then visible in `--failed`.
        StartLimitIntervalSec = 1800;
        StartLimitBurst = 5;
      };
      Service = {
        ExecStart = gioMount;
        Restart = "on-failure";
        RestartSec = "30s";
      };
      Install.WantedBy = [
        "graphical-session.target"
        "hyprland-session.target"
      ];
    };

    systemd.user.timers.mount-hydra-retry = {
      Unit.Description = "Retry Hydra GVfs mount";
      Timer = {
        OnBootSec = "2min";
        OnUnitInactiveSec = "5min";
        Unit = "mount-hydra.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
