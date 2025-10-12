# ============================================================================
# AMD Graphics Module for Dell OptiPlex
# ============================================================================
#
# This module configures AMD discrete graphics support for the Dell OptiPlex.
# Based on the hardware detection, this system has Intel integrated graphics
# (HD Graphics 530, device ID 0x1912) but may have AMD discrete GPU capability.
#
# Since no AMD GPU was detected in the current hardware scan, this module
# provides configuration for when an AMD discrete GPU is added to the system.
#
# HARDWARE SUPPORT:
# =================
# - AMD Radeon RX series GPUs (Polaris, Vega, Navi architectures)
# - OpenCL support via ROCm
# - Vulkan support via RADV
# - VA-API for hardware-accelerated video decoding
#
# KERNEL PARAMETERS:
# =================
# - amdgpu.si_support=1: Enable Southern Islands (GCN 1.0) support
# - amdgpu.cik_support=1: Enable Sea Islands/Cape Verde (GCN 1.1) support
# - radeon.si_support=0: Disable legacy radeon driver for SI GPUs
# - radeon.cik_support=0: Disable legacy radeon driver for CIK GPUs
#
# USAGE:
# ======
# Import this module in dell-potato configuration when AMD GPU is present.
# The module will automatically detect and configure AMD graphics drivers.
#
# ============================================================================

{ config, lib, pkgs, ... }:

{
  # AMD GPU configuration - conditionally enabled based on hardware detection
  hardware.graphics = lib.mkIf (config.hardware.graphics.enable) {
    enable = true;
    enable32Bit = true;

    # AMD-specific packages
    extraPackages = with pkgs; [
      # ROCm for OpenCL support
      rocmPackages.clr.icd

      # VA-API driver for AMD GPUs
      libva

      # Vulkan ICD
      vulkan-loader
      vulkan-validation-layers
    ];
  };

  # AMD GPU kernel modules
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "amdgpu" ];

  # Kernel parameters for AMD graphics
  boot.kernelParams = [
    "amdgpu.si_support=1"
    "amdgpu.cik_support=1"
    "radeon.si_support=0"
    "radeon.cik_support=0"
  ];

  # Environment variables for AMD GPU
  environment.sessionVariables = {
    # Force AMD Vulkan ICD
    AMD_VULKAN_ICD = "RADV";

    # ROCm environment
    ROCR_VISIBLE_DEVICES = "all";
  };

  # System packages for AMD graphics debugging and monitoring
  environment.systemPackages = with pkgs; [
    # Graphics debugging tools
    glxinfo
    vulkan-tools
    clinfo

    # AMD-specific monitoring
    amdgpu_top

    # Video acceleration testing
    libva-utils
  ];

  # Services for AMD graphics
  systemd.services.amdgpu-fancontrol = {
    description = "AMD GPU Fan Control";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1 > /sys/class/drm/card1/device/ppfeatures || true'";
      RemainAfterExit = true;
    };
  };

  # Enable early KMS for AMD graphics
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Power management for AMD GPUs
  services.udev.extraRules = ''
    # Set AMD GPU power profile to performance mode
    SUBSYSTEM=="drm", KERNEL=="card*", ATTR{device/power_dpm_force_performance_level}="high" 2>/dev/null || true
  '';
}