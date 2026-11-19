# NVIDIA proprietary driver configuration
# Import this module only on hosts with NVIDIA GPUs.
_: {
  flake.modules.nixos.nvidia =
    { config, pkgs, ... }:

    {
      # Early-load NVIDIA kernel modules for KMS/plymouth
      boot.initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

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

      # Live activation keeps the booted kernel. Match driver-bound services
      # to its ABI until reboot, when systemd uses the new native units.
      systemd.generators.nvidia-live-driver = pkgs.writeShellScript "nvidia-live-driver" ''
        set -eu
        test -r /sys/module/nvidia/version || exit 0
        loaded=$(</sys/module/nvidia/version)
        [[ "$loaded" != "${config.hardware.nvidia.package.version}" ]] || exit 0

        booted=/run/booted-system/etc
        graphics=$(${pkgs.gawk}/bin/awk 'index($2, "/run/opengl-driver") && !index($2, "-32") { print $NF; exit }' \
          "$booted/tmpfiles.d/graphics-driver.conf")
        test -e "$graphics/lib/libnvidia-cfg.so.$loaded"

        # New graphical clients must load the userspace for the running module.
        dir="$1/systemd-tmpfiles-resetup.service.d"
        ${pkgs.coreutils}/bin/mkdir -p "$dir"
        printf '[Service]\nExecStartPost=%s --create %s\n' \
          "${config.systemd.package}/bin/systemd-tmpfiles" "$booted/tmpfiles.d/graphics-driver.conf" \
          > "$dir/60-booted-nvidia.conf"

        for unit in nvidia-persistenced nvidia-container-toolkit-cdi-generator; do
          fragment="$booted/systemd/system/$unit.service"
          test -f "$fragment" || continue
          command=$(${pkgs.gnused}/bin/sed -n 's/^ExecStart=\(\/nix\/store\/.*\)/\1/p' "$fragment")
          test -n "$command"
          if [[ "$unit" == nvidia-persistenced ]]; then
            command+=" --nvidia-cfg-path=$graphics/lib"
          fi
          dir="$1/$unit.service.d"
          ${pkgs.coreutils}/bin/mkdir -p "$dir"
          printf '[Service]\nExecStart=\nExecStart=%s\n' "$command" > "$dir/60-booted-nvidia.conf"
        done
      '';

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
        egl-wayland
        nvidia-vaapi-driver
      ];
    };
}
