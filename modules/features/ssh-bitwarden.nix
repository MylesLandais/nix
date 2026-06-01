{
  config,
  lib,
  pkgs,
  ...
}:
let
  bw = lib.getExe pkgs.bitwarden-desktop;
  bwSock = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
  bwData = "${config.home.homeDirectory}/.config/Bitwarden/data.json";
in
{
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
        IdentityAgent ${bwSock}

      # Remote management for Optiplex nodes
      # TODO: Replace placeholder hostnames/IPs with actual Tailscale or LAN addresses
      Host opti-*
        User warby
        ForwardAgent yes

      # Cluster + installer unattended SSH path. Bypasses the Bitwarden SSH
      # agent so that automated recovery / iso-deploy keeps working when the
      # vault is locked or the agent socket is unavailable. Uses the on-disk
      # ed25519 key whose public half lives in modules/features/ssh-keys.nix.
      Host home-office-installer 94tl0m2 95qmom2 argus lacie dell-potato 192.168.0.* 100.107.*
        User warby
        IdentityFile ~/.ssh/id_ed25519
        IdentitiesOnly yes
        IdentityAgent none
    '';
  };

  # gcr-ssh-agent is disabled system-wide via services.gnome.gcr-ssh-agent.enable
  # in hosts/cerberus/configuration.nix so Bitwarden owns SSH_AUTH_SOCK.
  systemd.user.sessionVariables.SSH_AUTH_SOCK = bwSock;

  # Keep Bitwarden alive as a user service so the SSH agent socket stays live
  # after the launching terminal closes. Hyprland also starts it at login as a
  # fallback, but the service is the durable path.
  systemd.user.services.bitwarden = {
    Unit = {
      Description = "Bitwarden Desktop (SSH agent)";
      After = [
        "gnome-keyring.service"
        "graphical-session.target"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      # Remove stale socket left behind when Bitwarden crashes or is killed.
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${bwSock}";
      ExecStart = "${bw} --minimized";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [
      "graphical-session.target"
      "hyprland-session.target"
    ];
  };

  # Enable Bitwarden SSH agent in desktop settings (global_desktopSettings_sshAgentEnabled).
  # Bitwarden only creates ~/.bitwarden-ssh-agent.sock when this flag is true.
  home.activation.bitwardenSshAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f ${lib.escapeShellArg bwData} ]; then
      ${pkgs.jq}/bin/jq '
        .global_desktopSettings_sshAgentEnabled = true
        | .global_desktopSettings_sshAgentPromptBehavior = "rememberUntilLock"
      ' ${lib.escapeShellArg bwData} > ${lib.escapeShellArg bwData}.tmp
      mv ${lib.escapeShellArg bwData}.tmp ${lib.escapeShellArg bwData}
    fi
  '';
}
