# Shared nixpkgs overlays required by modules consumed across hosts
# (e.g. modules/firefox.nix needs pkgs.nur). Host-specific overlays
# (CachyOS kernel, cursor AppImage pin) stay on the host module.
{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.nur.overlays.default
    inputs.claude-code.overlays.default
    inputs.nix-vscode-extensions.overlays.default
  ];
}
