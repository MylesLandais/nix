{ config, pkgs, ... }:

{
  # Local services: code-server for remote VSCode access
  services.code-server = {
    enable = true;
    user = "franky";
    group = "users";
    host = "0.0.0.0";
    port = 8080;
    authenticator = "password";
    # Config via file for secrets
    config = ''
      bind-addr = 0.0.0.0:8080
      auth = password
       password = $(cat ${config.age.secrets.code-server-password.path})
      cert = false  # Enable HTTPS with Tailscale certs if needed
    '';
    extraPackages = with pkgs; [ nodejs yarn ];  # For extensions
  };

  # Firewall: Already opened 8080 on Tailscale in config
  # Extensions managed in home.nix for user reproducibility
}