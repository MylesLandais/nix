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
      codeServer  = {
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

          qdrant = {
            image = "qdrant/qdrant:latest";
            autoStart = true;
            ports = [
              "6333:6333" # HTTP API / Monitoring
              "6334:6334" # gRPC API
            ];
            volumes = [
              "/var/lib/qdrant/storage:/qdrant/storage"
              # Optional: If you want custom config, uncomment and create the file
              # "/var/lib/qdrant/config.yaml:/qdrant/config/production.yaml"
            ];
            environment = {
              # Default logging level
              QDRANT__LOG_LEVEL = "INFO";
            };
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
          # ComfyUI with GPU support
          # comfy = {
          #   image = "ghcr.io/clsferguson/comfyui-docker:latest"; # Using a community-maintained, up-to-date image
          #   autoStart = true;
          #   ports = [ "8188:8188" ];
          #   extraOptions = [
          #     "--device=nvidia.com/gpu=all"
          #     "--ipc=host"
          #   ];
          #   volumes = [
          #     "/home/warby/ComfyUI/user:/app/ComfyUI/user"          # Workflows, settings
          #     "/home/warby/ComfyUI/custom_nodes:/app/ComfyUI/custom_nodes" # Extensions
          #     "/home/warby/ComfyUI/models:/app/ComfyUI/models:rw"      # Model checkpoints
          #     "/home/warby/ComfyUI/input:/app/ComfyUI/input:rw"       # Images for generation
          #     "/home/warby/ComfyUI/output:/app/ComfyUI/output:rw"     # Generated images/videos
          #   ];
          #   environment = {
          #     TZ = "America/Chicago";
          #     PUID = "1000";
          #     PGID = "1000";
          #     COMFY_AUTO_INSTALL = "1"; # Automatically install python packages for custom_nodes
          #   };
          # };

          vllm = {
            image = "vllm/vllm-openai:latest";
            autoStart = false;
            ports = [ "8000:8000" ];
            extraOptions = [
              "--device=nvidia.com/gpu=all"
              "--ipc=host"
            ];
            volumes = [
              "/home/warby/.cache/huggingface:/root/.cache/huggingface"
            ];
            environment = {
              TZ = "America/New_York";
            };
            cmd = [ "--model" "Qwen/Qwen2.5-0.5B" ];
          };
        };
      };
    };

    # Open firewall for code-server port
    networking.firewall.allowedTCPPorts = [
      config.dev.containers.codeServer.port
      8000
      # 8188  # ComfyUI port (disabled)
    ];

    # Add useful packages
    environment.systemPackages = with pkgs; [
      lazydocker
      # inputs.kiro.packages.${system}.default  # TODO: Add kiro input to flake.nix if needed
    ];

    # FIX: Workaround for nvidia-container-toolkit issue
    # https://github.com/NixOS/nixpkgs/issues/463525
    systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStartPre = lib.mkForce null;
  };
}
