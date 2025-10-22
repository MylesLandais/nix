{
  config,
  lib,
  pkgs,
  ...
}:

{

  options.dev = {
    enable = lib.mkEnableOption "Enable developer tooling module" // {
      default = true;
    };

    containers = {
      codeServer = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "linuxserver/code-server:latest";
          description = "Docker image for code-server container";
        };
        ports = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "8080:8080" ];
          description = "Port mappings for code-server";
        };
      };
      portainer = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "portainer/portainer-ce:latest";
          description = "Docker image for Portainer container";
        };
        ports = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "0.0.0.0:9000:9000" ];
          description = "Port mappings for Portainer";
        };
      };
      chromeRemote = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "selenium/standalone-chrome-debug:alpine";
          description = "Docker image for Chrome remote container";
        };
        ports = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "4444:4444"
            "5900:5900"
            "7900:7900"
            "9222:9222"
          ];
          description = "Port mappings for Chrome remote";
        };
        vncPassword = lib.mkOption {
          type = lib.types.str;
          default = "devsandbox123";
          description = "VNC password for Chrome remote";
        };
      };
    };
  };

  config = lib.mkIf config.dev.enable {

    system.activationScripts.devContainerSetup =
      let
        hostname = config.networking.hostName;
      in
      ''
        mkdir -p /var/lib/code-server-certs
        if [ ! -f /var/lib/code-server-certs/cert.pem ]; then
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 -keyout /var/lib/code-server-certs/key.pem -out /var/lib/code-server-certs/cert.pem -days 365 -nodes -subj "/CN=localhost"
        fi
        mkdir -p /var/lib/code-server-${hostname}/data/User
        echo '{"workbench.colorTheme": "Tokyo Night"}' > /var/lib/code-server-${hostname}/data/User/settings.json
        chown -R 1000:1000 /var/lib/code-server-${hostname}

        # Load custom minimal images - removed
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
          runAsRoot = false;
        };
      };
      oci-containers = {
        backend = "docker";
        containers = {
          "code-server" = {
            image = config.dev.containers.codeServer.image;
            ports = config.dev.containers.codeServer.ports;
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/var/lib/code-server-${config.networking.hostName}:/config"
              "/home/warby/Workspace:/workspace"
              "/var/lib/code-server-certs:/certs"
            ];
            environment = {
              PASSWORD = "devsandbox123";
              TZ = "America/New_York";
              PUID = "1000";
              PGID = "1000";
            };
            cmd = [
              "--bind-addr"
              "0.0.0.0:8080"
              "--cert"
              "/certs/cert.pem"
              "--cert-key"
              "/certs/key.pem"
            ];
            autoStart = true;
          };
          "portainer" = {
            image = config.dev.containers.portainer.image;
            ports = config.dev.containers.portainer.ports;
            volumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
              "/var/lib/portainer-${config.networking.hostName}:/data"
            ];
            environment = {
              TZ = "America/New_York";
            };
            autoStart = true;
          };
          "chrome-remote" = {
            image = config.dev.containers.chromeRemote.image;
            ports = config.dev.containers.chromeRemote.ports;
            volumes = [
              "/dev/shm:/dev/shm"
              "/var/lib/chrome-remote-${config.networking.hostName}:/home/seluser/.config/google-chrome"
            ];
            environment = {
              TZ = "America/New_York";
              SE_VNC_PASSWORD = config.dev.containers.chromeRemote.vncPassword;
              SE_OPTS = "--disable-blink-features=AutomationControlled --disable-dev-shm-usage --no-sandbox --disable-gpu --user-agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'";
            };
            autoStart = true;
          };
          # "livebook" = {
          #   image = config.dev.containers.livebook.image;
          #   ports = config.dev.containers.livebook.ports;
          #  volumes = [
          #    "/home/warby/Workspace/Kino:/data"
          #  ];
          #  environment = {
          #    TZ = "America/New_York";
          #    LIVEBOOK_PASSWORD = "devsandbox123";
          #    LIVEBOOK_DATA_PATH = "/data";
          #  };
          #  autoStart = true;
          # };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      9000
      8080
      8081
      4444
      5900
      7900
      9222
    ];

    # PostgreSQL service for Phoenix development
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "phoenix_dev" ];
      authentication = pkgs.lib.mkOverride 10 ''
        #type database  DBuser  auth-method
        local all       all     trust
      '';
    };

    environment.systemPackages = with pkgs; [
      docker-compose
      lazydocker
      virt-manager
      elixir
      nodejs
      postgresql
      inotify-tools
      remmina
      python3Packages.selenium
    ];

    users.groups.libvirtd.members = [ ];
    users.groups.docker.members = [ ];
  };
}
