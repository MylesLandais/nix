_: {
  flake.modules.nixos.security =
    {
      lib,
      pkgs,
      ...
    }:
    {
      security.polkit.enable = true;

      nixpkgs.overlays = [
        (_final: prev: {
          # Bitwarden uses a private keyring daemon only in its build tests.
          # Keep that dependency stock so Hydra's desktop binary can be used.
          bitwarden-desktop = prev.bitwarden-desktop.override { inherit (prev) gnome-keyring; };
          gnome-keyring = prev.gnome-keyring.overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or [ ]) ++ [
              ./_patches/gnome-keyring-opensession-race.patch
            ];
          });
        })
      ];

      services.gnome.gnome-keyring.enable = true;
      services.gnome.gcr-ssh-agent.enable = false;
      programs.seahorse.enable = true;

      services.dbus.packages = [ pkgs.gcr_3 ];
      environment.systemPackages = [ pkgs.gcr_3 ];

      # Replace NixOS's default x11_ssh_askpass with the GTK-themed seahorse one
      # so any residual askpass prompt (from sub-tools, sudo-over-ssh, etc.)
      # matches the system aesthetic instead of dropping a 1999 Tk popup.
      programs.ssh.askPassword = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

      # PAM login integration so the keyring auto-unlocks at SDDM / greetd / tty login.
      security.pam.services.login.enableGnomeKeyring = true;
      security.pam.services.sddm.enableGnomeKeyring = true;
      security.pam.services.greetd.enableGnomeKeyring = true;

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
    };
}
