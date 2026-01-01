{ config, lib, pkgs, ... }:

{
  options = {
    vscode-ai.enable = lib.mkEnableOption "Enable VS Code AI extension permissions fix";
  };

  config = lib.mkIf config.vscode-ai.enable {
    # 1. Fix Permissions: Ensure globalStorage directories exist and are writable.
    # This runs every time you switch configuration to fix permissions if they get reset.
    home.activation.fixVsCodeExtensionsPermissions = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Define the extension storage paths
      KILO_DIR="$HOME/.config/Code/User/globalStorage/kilo-org.kilocode"
      ROO_DIR="$HOME/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline"

      # Create directories if they don't exist
      mkdir -p "$KILO_DIR"
      mkdir -p "$ROO_DIR"

      # Ensure the user has write permissions (chmod 755 or 700)
      chmod -R u+rwX "$KILO_DIR"
      chmod -R u+rwX "$ROO_DIR"
    '';

    # 2. Pre-configure Auto-Approval settings in VS Code
    programs.vscode.profiles.default.userSettings = {
      "kilo.autoApproval.enabled" = true;
      "roo-cline.autoApproval.enabled" = true;
    };
  };
}
