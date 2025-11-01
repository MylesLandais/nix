# Additional fixes for Hyprland display/keyboard issue
# Apply these if the primary fix (commenting out nvidia_drm.modeset=1) doesn't work

# Fix 2: Add explicit display manager (SDDM with Wayland support)
{
  services.xserver.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings = {
      Theme = {
        # Use a simple theme to avoid rendering issues
        Current = "breeze";
      };
    };
  };
}

# Fix 3: Disable USB autosuspend to prevent device resets
{
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];
  
  services.udev.extraRules = ''
    # Prevent USB controller resets during session changes
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    
    # Ensure input devices stay powered
    SUBSYSTEM=="input", ATTR{power/autosuspend}="0"
    SUBSYSTEM=="input", ATTR{power/control}="on"
  '';
}

# Fix 4: Alternative NVIDIA configuration (if open driver causes issues)
{
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;  # Try enabling power management
    powerManagement.finegrained = false;
    open = false;  # Use proprietary driver instead of open
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;  # Use stable instead of latest
  };
}

# Fix 5: Improve Hyprland session management
{
  # Ensure proper session handoff
  services.displayManager.sessionPackages = [ pkgs.hyprland ];
  
  # Add environment variables for better NVIDIA/Wayland compatibility
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };
}

# Fix 6: Systemd user session improvements
{
  systemd.user.services.hyprland-session = {
    Unit = {
      Description = "Hyprland Wayland Session";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP";
    };
  };
}