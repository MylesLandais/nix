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
      # hydra (Unraid) — passphrase-less automation/support-agent key. MUST precede the
      # "Host *" block below so IdentityAgent/IdentityFile win (ssh takes the first value
      # per option). Bypasses the Bitwarden agent (whose key hydra doesn't accept) and the
      # passphrase-locked id_ed25519. Pubkey persists on hydra flash root.pubkeys.
      Host hydra
        HostName 192.168.0.222
        User root
        IdentityFile ~/.ssh/homelab_admin
        IdentitiesOnly yes
        IdentityAgent none

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
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
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
  #
  # Key names come from DesktopSettingsService in the app bundle, and the two settings are
  # scoped differently:
  #   SSH_AGENT_ENABLED         = KeyDefinition     "sshAgentEnabled"                -> global_*
  #   SSH_AGENT_PROMPT_BEHAVIOR = UserKeyDefinition "sshAgentRememberAuthorizations" -> user_<uuid>_*
  # There is no global prompt-behavior key; writing one is a no-op, so the user-scoped key is
  # built from the active account id. Note the disk key does NOT match the in-app name
  # "sshAgentPromptBehavior", which only appears as an i18n string and form control id.
  home.activation.bitwardenSshAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f ${lib.escapeShellArg bwData} ]; then
      ${pkgs.jq}/bin/jq '
        .global_account_activeAccountId as $uid
        | .global_desktopSettings_sshAgentEnabled = true
        | del(.global_desktopSettings_sshAgentPromptBehavior)
        | if $uid then
            .["user_" + $uid + "_desktopSettings_sshAgentRememberAuthorizations"] = "rememberUntilLock"
          else . end
      ' ${lib.escapeShellArg bwData} > ${lib.escapeShellArg bwData}.tmp
      mv ${lib.escapeShellArg bwData}.tmp ${lib.escapeShellArg bwData}
    fi
  '';
}
