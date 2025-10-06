# ============================================================================
# Agenix Secrets Management Module
# ============================================================================
#
# This module configures agenix for secure secrets management in NixOS.
# Agenix uses age encryption (modern alternative to PGP) to store sensitive
# data like API keys, passwords, and authentication tokens.
#
# HOW IT WORKS:
# =============
# 1. Secrets are encrypted using age public keys
# 2. Encrypted files (.age) are stored in the secrets/ directory
# 3. At build time, agenix decrypts secrets to /run/secrets/
# 4. Services access decrypted secrets via config.age.secrets.<name>.path
#
# SETUP REQUIREMENTS:
# ===================
# 1. Generate age keypair: agenix -i ~/.ssh/id_ed25519 -g
# 2. Add public key to .sops.yaml or directly in secret files
# 3. Encrypt secrets: agenix -e secrets/secret.txt
# 4. Reference in services: ${config.age.secrets.secret.path}
#
# CURRENT SECRETS:
# ================
# - tailscale-auth-key: Tailscale authentication key for VPN
# - code-server-password: Password for remote code-server access
# - ollama: Configuration for Ollama AI service
#
# SECURITY NOTES:
# ===============
# - Secrets are only decrypted at runtime, not stored in /nix/store
# - Access is restricted by owner/group permissions
# - Public keys should be committed; private keys stay local
#
# ============================================================================

{ config, lib, pkgs, ... }:

{
  # Agenix for secrets management
  age = {
    secrets = {
      tailscale-auth-key = {
        file = ../../secrets/tailscale-auth-key.age;
        owner = "root";
      };
      code-server-password = {
        file = ../../secrets/code-server-password.age;
        owner = "franky";
      };
      ollama = {
        file = ../../secrets/ollama.age;
        owner = "root";
      };
    };
  };

  environment.systemPackages = [ inputs.agenix.packages.${pkgs.system}.agenix ];
}