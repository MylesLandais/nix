{ config, pkgs, ... }: {
  # System-level: Enable daemon, PAM integration, and D-Bus
  services.dbus.enable = true;
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;  # Optional: GUI for keyring management/debug

  # Ensure Wayland/Hyprland session vars for keyring detection
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
  };

  # PAM for auto-unlock on login (for tty/Hyprland start)
  security.pam.services.login.enableGnomeKeyring = true;

  # System packages for compatibility
  environment.systemPackages = with pkgs; [
    gnome.gnome-keyring
    gnome.libgnome-keyring  # Legacy support for apps like VS Code
    libsecret  # For secret-tool CLI if needed for testing
  ];

  # Home Manager integration (user-level autostart and components)
  home-manager.users.warby = {
    services.gnome-keyring = {
      enable = true;
      components = [ "pkcs11" "secrets" "ssh" ];  # Enable all needed components
    };
  };
}