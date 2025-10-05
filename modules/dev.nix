{ config, pkgs, ... }:

{

  # Shared developer tooling for all hosts: Docker, libvirtd, Portainer
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
    };
    libvirtd = {
      enable = true;
      qemu = {
        ovmf.enable = true;
        runAsRoot = false;
      };
    };
    oci-containers = {
      backend = "docker";
      containers = {
        "portainer" = {
          image = "portainer/portainer-ce:latest";
          ports = [ "9000:9000" ];
          volumes = [
            "/var/run/docker.sock:/var/run/docker.sock"
            "/var/lib/portainer:/data"
          ];
          environment = {
            TZ = "America/New_York";
          };
          autoStart = true;
        };
        "code-server" = {
          image = "codercom/code-server:latest";
          ports = [ "8080:8080" ];
          volumes = [
            "/var/run/docker.sock:/var/run/docker.sock"
            "/var/lib/code-server:/home/coder/.config"
            "/home/warby/Workspace:/home/coder/workspace"
            "/var/lib/code-server-certs:/certs"
          ];
          environment = {
            PASSWORD = "devsandbox123";
            TZ = "America/New_York";
            CERT_FILE = "/certs/cert.pem";
            KEY_FILE = "/certs/key.pem";
          };
          user = "1000";
          cmd = [ "--bind-addr" "0.0.0.0" "--port" "8080" "--cert" "/certs/cert.pem" "--cert-key" "/certs/key.pem" ];
          autoStart = true;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 9000 8080 ];

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    virt-manager
    elixir
    nodejs
    postgresql
  ];

  users.groups.libvirtd.members = [ ];
  users.groups.docker.members = [ ];
}
