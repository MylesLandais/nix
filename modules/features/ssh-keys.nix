{ config, ... }:
{
  users.users.warby.openssh.authorizedKeys.keys = [
    # Personal device identities (passphrase-protected on disk; decrypted by
    # the user-facing agent during interactive ssh).
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQPlTg3O6tXvjOO8+hVGWfu7tr2lzgAdu+EFVNV2BYY landais.myles@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONcu7pQIpReczEW77P9eW7vtte0PTVs9gGck/wyNVYZ warby@warbpad"

    # Bitwarden-managed automation identity. The Bitwarden desktop SSH agent
    # holds this key unlocked while the vault is open, which lets cerberus
    # (and other control hosts) run unattended ssh to cluster/installer nodes
    # without exposing a cleartext private key on disk. Loaded via
    # SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock — see ssh-bitwarden.nix.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN26TcFkEK22/wuioiuHxCKZw0C1cdkVzgGMA+m7Jeei cerberus-bitwarden-automation"
  ];

  # Mirror warby's keys to root so a single user-account drift can never strand
  # us. PermitRootLogin = prohibit-password keeps password auth blocked.
  users.users.root.openssh.authorizedKeys.keys =
    config.users.users.warby.openssh.authorizedKeys.keys;

  services.openssh.settings.PermitRootLogin = "prohibit-password";
}
