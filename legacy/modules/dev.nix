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
  };

  config = lib.mkIf config.dev.enable {

    hardware.nvidia-container-toolkit.enable = true;

    virtualisation = {
      docker = {
        enable = true;
        # Socket-activate Docker instead of starting at boot (saves ~1min)
        # oci-containers will still auto-start via their dependency on docker.service
        enableOnBoot = false;
      };

      oci-containers = {
        backend = "docker";
        containers = {
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

    networking.firewall.allowedTCPPorts = [
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
