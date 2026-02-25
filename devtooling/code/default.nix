{ config, lib, pkgs, ... }:
{
  options.code.enable = lib.mkEnableOption "Enable VS Code AI extensions";

  config = lib.mkIf config.code.enable {
    programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
      kilocode.kilo-code
      rooveterinaryinc.roo-cline
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "kimi-code";
          publisher = "moonshot-ai";
          version = "0.4.3";
          arch = "linux-x64";
          hash = "sha256-aNiAjE/O/dBmfrFEHUIr/82kQIY3FfJqIbtdMAeyfCo=";
        };
      })
    ];

    home.activation.fixVsCodeExtensionsPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      KILO_DIR="$HOME/.config/Code/User/globalStorage/kilo-org.kilocode"
      ROO_DIR="$HOME/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline"
      KIMI_DIR="$HOME/.config/Code/User/globalStorage/moonshot-ai.kimi-code"
      mkdir -p "$KILO_DIR" "$ROO_DIR" "$KIMI_DIR"
      chmod -R u+rwX "$KILO_DIR" "$ROO_DIR" "$KIMI_DIR"
    '';

    programs.vscode.profiles.default.userSettings = {
      "kilo.autoApproval.enabled" = true;
      "roo-cline.autoApproval.enabled" = true;
      "kimi-code.autoApproval.enabled" = true;
    };
  };
}
