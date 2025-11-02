{
  config,
  lib,
  pkgs,
  inputs,
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
        port = lib.mkOption {
          type = lib.types.int;
          default = 8080;
          description = "Port for code-server";
        };
        password = lib.mkOption {
          type = lib.types.str;
          default = "devsandbox123";
          description = "Password for code-server";
        };
      };
    };
  };

  config = lib.mkIf config.dev.enable {
    # Enable Podman for container management
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };
      
      oci-containers = {
        backend = "podman";
        containers = {
          "code-server" = {
            image = config.dev.containers.codeServer.image;
            ports = [ "${toString config.dev.containers.codeServer.port}:8443" ];
            volumes = [
              "/home/warby/Workspace:/home/coder/Workspace"
              "/home/warby/.config/code-server/settings.json:/config/code-server/settings.json"
              "/home/warby/.config/code-server/extensions:/config/code-server/extensions"
            ];
            environment = {
              PASSWORD = config.dev.containers.codeServer.password;
              TZ = "America/New_York";
              PUID = "1000";
              PGID = "1000";
              DEFAULT_WORKSPACE = "/home/coder/Workspace";
            };
            # No custom cmd needed for linuxserver image
            # It uses environment variables for configuration
            autoStart = true;
          };
        };
      };
    };

    # Open firewall for code-server port
    networking.firewall.allowedTCPPorts = [ config.dev.containers.codeServer.port ];

    # Add useful packages
    environment.systemPackages = with pkgs; [
      podman-compose
      lazydocker
      inputs.kiro.packages.${system}.default
    ];
    # Add user to podman group
    users.groups.podman.members = [ "warby" ];
  };
}
