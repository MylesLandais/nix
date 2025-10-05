{ config, pkgs, ... }:

{
  # Developer tooling: Docker, groups, packages
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    socketBinding = "tcp://0.0.0.0:2375";  # Optional: Expose socket for remote access via Tailscale
  };

  users.extraGroups.docker.members = [ "franky" ];

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    # Add other dev tools as needed
  ];

  # Firewall for Docker if exposing socket
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 2375 ];  # Docker socket port

  # NVIDIA runtime for Docker (since kraken has NVIDIA)
  virtualisation.docker.enableNvidia = true;
}