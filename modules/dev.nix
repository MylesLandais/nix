{ config, pkgs, ... }:

{
  # Shared developer tooling for all hosts: Docker, libvirtd, Portainer
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      # Optional: Expose socket for remote (secure with Tailscale ACLs)
      # socketBinding = "tcp://127.0.0.1:2375";  # Bind to localhost or Tailscale IP
    };
    libvirtd = {
      enable = true;
      qemu = {
        ovmf.enable = true;  # For UEFI VMs
        runAsRoot = false;
      };
    };
    oci-containers = {
      enable = true;
      backend = "docker";  # Use Docker backend
        containers = {
          "portainer" = {
            image = "portainer/portainer-ce:latest";
            ports = [ "9000:9000" ];
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/var/lib/portainer:/data"  # Persistent data
            ];
            environment = {
              TZ = "Europe/Madrid";  # Match your timezone
            };
            autoStart = true;
          };
          "code-server" = {
            image = "coder/code-server:latest";
            ports = [ "8080:8080" ];
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/var/lib/code-server:/home/coder/.config/code-server"  # Persistent config
              # Add your workspace: e.g., "/home/franky/dev:/home/coder/project"
            ];
            environment = {
              PASSWORD = "admin";  # Change this to a secure password
              TZ = "Europe/Madrid";
            };
            autoStart = true;
          };
        };

    };
  };

  # Firewall: Open ports for Portainer and code-server on Tailscale
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 9000 8080 ];

  # System packages for dev (docker-compose, etc.)
  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    virt-manager  # For libvirt GUI if needed

    # Elixir and Phoenix development
    elixir
    nodejs
    postgresql
    mix-test.watch
  ];

  # Generic groups; add users per-host
  users.groups.libvirtd.members = [ ];  # Populate per-host
  users.groups.docker.members = [ ];    # Populate per-host
}
