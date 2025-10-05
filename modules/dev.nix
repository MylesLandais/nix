{ config, pkgs, ... }:

let
  customCodeServerImage = pkgs.dockerTools.buildImage {
    name = "code-server-custom";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "codercom/code-server";
      imageDigest = "sha256:6edc8e2d2849749c1a1a5eff8e76563b96db407e68899c143473a6004d0a6b5a";
      sha256 = "sha256-xSd/TPS72jca1dXSwTGT5kFsyV8slsb3gXTzXEYauB4=";
    };
    runAsRoot = ''
      #!${pkgs.runtimeShell}
      mkdir -p /home/coder/.local/share/code-server/User
      echo '{"workbench.colorTheme": "Tokyo Night"}' > /home/coder/.local/share/code-server/User/settings.json
      chown -R 1000:1000 /home/coder/.local
    '';
    config = {
      Cmd = [ "--bind-addr" "0.0.0.0:8080" ];
      User = "1000";
    };
  };
in

{

  system.activationScripts.loadCodeServerImage = ''
    ${pkgs.docker}/bin/docker load < ${customCodeServerImage} || true
    mkdir -p /var/lib/code-server-certs
    if [ ! -f /var/lib/code-server-certs/cert.pem ]; then
      ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -keyout /var/lib/code-server-certs/key.pem -out /var/lib/code-server-certs/cert.pem -days 365 -nodes -subj "/CN=localhost"
    fi
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
           image = "code-server-custom";
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
             CERT_FILE = "/certs/cert.pem";
             KEY_FILE = "/certs/key.pem";
           };
           user = "1000";
            cmd = [ "sh" "-c" "code-server --install-extension enkia.tokyo-night && code-server --bind-addr 0.0.0.0:8080 --cert /certs/cert.pem --cert-key /certs/key.pem" ];
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
