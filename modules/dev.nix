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

    hardware.nvidia-container-toolkit.enable = true;

    virtualisation = {
      docker = {
        enable = true;
      };

      oci-containers = {
        backend = "docker";
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
          neo4j = {
            image = "neo4j:latest";
            ports = [
              "7474:7474"
              "7687:7687"
            ];
            volumes = [
              "/var/lib/neo4j/data:/data"
              "/var/lib/neo4j/logs:/logs"
              "/var/lib/neo4j/import:/var/lib/neo4j/import"
              "/var/lib/neo4j/plugins:/plugins"
            ];
            environment = {
              NEO4J_AUTH = "neo4j/password"; # Big ups default creds TT
            };
          };
          jupyter = {
            image = "quay.io/jupyter/pytorch-notebook:cuda12-python-3.11.9";
            autoStart = true;

            ports = [
              "8888:8888"
            ];

            # GPU support for NVIDIA
            extraOptions = [
              "--device=nvidia.com/gpu=all"
              "--ipc=host"
            ];

            volumes = [
              "/home/warby/Workspace:/home/jovyan/work:rw"
              "/home/warby/.jupyter:/home/jovyan/.jupyter:rw"
            ];

            environment = {
              JUPYTER_ENABLE_LAB = "yes";
              TZ = "America/New_York";
              PUID = "1000";
              PGID = "1000";
            };
          };
        };
      };
    };

    # Open firewall for code-server port
    networking.firewall.allowedTCPPorts = [ config.dev.containers.codeServer.port ];

    # Add useful packages
    environment.systemPackages = with pkgs; [
      lazydocker
      # inputs.kiro.packages.${system}.default  # TODO: Add kiro input to flake.nix if needed
    ];
  };
}
