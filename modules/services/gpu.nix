_: {
  flake.nixosModules.gpu =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      # Always enable graphics (needed by both AMD and NVIDIA)
      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };

        # AMD GPU configuration
        amdgpu = lib.mkIf (config.host.gpuType == "amd") {
          overdrive.enable = true;
          opencl.enable = true;
          initrd.enable = true;
        };

        # NVIDIA GPU configuration
        nvidia = lib.mkIf (config.host.gpuType == "nvidia") {
          modesetting.enable = true;
          powerManagement.enable = false;
          open = false;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
        };
      };

      # GPU tools — conditional per GPU type
      systemd.packages = lib.mkIf (config.host.gpuType == "amd") (with pkgs; [ lact ]);
      systemd.services.lactd.wantedBy = lib.mkIf (config.host.gpuType == "amd") [ "multi-user.target" ];
      environment.systemPackages =
        (lib.optionals (config.host.gpuType == "amd") (
          with pkgs;
          [
            lact
            nvtopPackages.amd
          ]
        ))
        ++ (lib.optionals (config.host.gpuType == "nvidia") (with pkgs; [ nvtopPackages.nvidia ]));

      services.xserver.videoDrivers = lib.mkIf (config.host.gpuType == "nvidia") [ "nvidia" ];
    };
}
