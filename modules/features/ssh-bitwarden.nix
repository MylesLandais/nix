{
  config,
  lib,
  ...
}:
{
  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
        IdentityAgent ${config.home.homeDirectory}/.bitwarden-ssh-agent.sock

      # Remote management for Optiplex nodes
      # TODO: Replace placeholder hostnames/IPs with actual Tailscale or LAN addresses
      Host opti-*
        User warby
        ForwardAgent yes
    '';
  };
}
