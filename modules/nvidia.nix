# NVIDIA proprietary driver configuration
# Import this module only on hosts with NVIDIA GPUs.

{ config, pkgs, ... }:

{
  # Early-load NVIDIA kernel modules for KMS/plymouth
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # Hardware-accelerated graphics (OpenGL/Vulkan)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaPersistenced = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Session-wide env vars for NVIDIA under Wayland
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };

  # GPU diagnostic tools
  environment.systemPackages = with pkgs; [
    libva-utils
    nvtopPackages.nvidia
    vulkan-tools
    vulkan-validation-layers
    egl-wayland
    nvidia-vaapi-driver
  ];
}
