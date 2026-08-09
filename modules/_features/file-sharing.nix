{
  lib,
  pkgs,
  ...
}:
{
  # Hydra (Unraid): short name for smb://hydra/… in Nemo and gio mount
  networking.hosts."192.168.0.222" = [
    "hydra"
    "hydra.local"
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
  };

  # Full GNOME GVfs (includes SMB); required for Nemo "Network" / smb:// on Hyprland.
  services.gvfs = {
    enable = true;
    package = lib.mkForce pkgs.gnome.gvfs;
  };
  services.udisks2.enable = true;
  services.tumbler.enable = true;
}
