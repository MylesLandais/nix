{
  lib,
  pkgs,
  ...
}:
{
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;
  programs.seahorse.enable = true;

  # Replace NixOS's default x11_ssh_askpass with the GTK-themed seahorse one
  # so any residual askpass prompt (from sub-tools, sudo-over-ssh, etc.)
  # matches the system aesthetic instead of dropping a 1999 Tk popup.
  programs.ssh.askPassword = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

  # PAM login integration so the keyring auto-unlocks at greetd / tty login.
  security.pam.services.login.enableGnomeKeyring = true;

  # Allow wheel group to mount filesystems without password
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Passwordless commands for development operations
  security.sudo.extraRules = [
    {
      users = [ "warby" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.git}/bin/git";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
        # lacie USB boot loop — QEMU tests, ISO staging, GRUB refresh
        {
          command = "/home/warby/.config/nixos/scripts/test-usb-qemu.sh";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/home/warby/.config/nixos/scripts/setup-nix-usb.sh";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/home/warby/.config/nixos/scripts/stage-installer-iso.sh";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/home/warby/.config/nixos/scripts/iso-deploy.sh";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/home/warby/.config/nixos/scripts/write-kali-usb.sh";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/run/current-system/sw/bin/mount";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
        {
          command = "/run/current-system/sw/bin/umount";
          options = [
            "NOPASSWD"
            "SETENV"
          ];
        }
      ];
    }
  ];
}
