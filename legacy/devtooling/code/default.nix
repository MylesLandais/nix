{ config, lib, pkgs, ... }:
{
  options.code.enable = lib.mkEnableOption "Enable VS Code AI extensions";

  config = lib.mkIf config.code.enable {
    programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
      kilocode.kilo-code
      rooveterinaryinc.roo-cline
    ];

    home.activation.fixVsCodeExtensionsPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      KILO_DIR="$HOME/.config/Code/User/globalStorage/kilo-org.kilocode"
      ROO_DIR="$HOME/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline"
      mkdir -p "$KILO_DIR" "$ROO_DIR"
      chmod -R u+rwX "$KILO_DIR" "$ROO_DIR"
    '';

    programs.vscode.profiles.default.userSettings = {
      "kilo.autoApproval.enabled" = true;
      "roo-cline.autoApproval.enabled" = true;
    };
  };
}
