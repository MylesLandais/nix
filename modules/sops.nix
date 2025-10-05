{ config, lib, pkgs, ... }:

{
  # Shared sops-nix for secrets management (Tailscale keys, passwords)
  sops = {
    defaultSopsFile = ../../secrets/secrets.nix;  # Your existing secrets file
    age = {
      keyFile = "/etc/age/age.agekey";  # Or ~/.config/sops/age/keys.txt for user
      generateKey = false;  # Generate if needed: age-keygen -o age.agekey
    };
    gnupg.sshKeyPaths = [ ];  # Optional: Use SSH keys for decryption
  };

  # Create age key dir and set permissions
  sops.age.keyFile = "/etc/sops/age/age.agekey";  # System-wide for services
  environment.systemPackages = [ pkgs.sops ];
}