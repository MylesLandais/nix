# Shared nixpkgs overlays required by modules consumed across hosts
# (e.g. modules/firefox.nix needs pkgs.nur). Host-specific overlays
# (CachyOS kernel, cursor AppImage pin) stay on the host module.
{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.nur.overlays.default
    inputs.claude-code.overlays.default
    inputs.nix-vscode-extensions.overlays.default
    # Buzz has no upstream Nix packaging, so it is repackaged from the official
    # .deb. Shared rather than host-local because nothing about it is host-specific;
    # only desktop hosts pull env-packages.nix and actually build it.
    (import "${inputs.self}/modules/_features/overlays/buzz-desktop.nix")
    # Kimi Code 0.34.0 (new standalone CLI) — provides bin/kimi and bin/kimi-code.
    (import "${inputs.self}/modules/_features/overlays/kimi-code.nix")
  ];
}
