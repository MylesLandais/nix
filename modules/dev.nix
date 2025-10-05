{ config, pkgs, ... }:



{

  system.activationScripts.codeServerSetup = ''
    mkdir -p /var/lib/code-server-certs
    if [ ! -f /var/lib/code-server-certs/cert.pem ]; then
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -keyout /var/lib/code-server-certs/key.pem -out /var/lib/code-server-certs/cert.pem -days 365 -nodes -subj "/CN=localhost"
    fi
    mkdir -p /var/lib/code-server-local/share/code-server/User
    echo '{"workbench.colorTheme": "Tokyo Night"}' > /var/lib/code-server-local/share/code-server/User/settings.json
    chown -R 1000:1000 /var/lib/code-server-local
  '';

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
         "code-server" = {
           image = "codercom/code-server:latest";
           ports = [ "8080:8080" ];
           volumes = [
             "/var/run/docker.sock:/var/run/docker.sock"
             "/var/lib/code-server:/home/coder/.config"
             "/var/lib/code-server-local:/home/coder/.local"
             "/home/warby/Workspace:/home/coder/workspace"
             "/var/lib/code-server-certs:/certs"
           ];
           environment = {
             PASSWORD = "devsandbox123";
             TZ = "America/New_York";
           };
           user = "1000";
           cmd = [ "--bind-addr" "0.0.0.0:8080" "--cert" "/certs/cert.pem" "--cert-key" "/certs/key.pem" ];
           autoStart = true;
         };
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
        "chrome-remote" = {
           image = "selenium/standalone-chrome-debug:latest";
           ports = [ "4444:4444" "5900:5900" "7900:7900" "9222:9222" ];
           volumes = [
             "/dev/shm:/dev/shm"
           ];
           environment = {
             TZ = "America/New_York";
             SE_VNC_PASSWORD = "devsandbox123";
           };
           autoStart = true;
         };
         "livebook" = {
           image = "ghcr.io/livebook-dev/livebook:latest";
           ports = [ "8081:8080" ];
           volumes = [
             "/home/warby/Workspace/Kino:/data"
           ];
           environment = {
             TZ = "America/New_York";
             LIVEBOOK_PASSWORD = "devsandbox123";
             LIVEBOOK_DATA_PATH = "/data";
           };
           autoStart = true;
         };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 9000 8080 8081 4444 5900 7900 9222 ];

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    virt-manager
    elixir
    nodejs
    postgresql
    remmina
  ];

  users.groups.libvirtd.members = [ ];
  users.groups.docker.members = [ ];
}
