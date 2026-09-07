# Shared nixpkgs overlays required by modules consumed across hosts
# (e.g. modules/firefox.nix needs pkgs.nur). Host-specific overlays
# (CachyOS kernel, cursor AppImage pin) stay on the host module.
{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.nur.overlays.default
    inputs.claude-code.overlays.default
    inputs.nix-vscode-extensions.overlays.default
    # Stable PCSX2 fast-path: reuse nixpkgs' build recipe while pinning the
    # immutable upstream release and patches snapshot locally.
    (import "${inputs.self}/modules/_features/overlays/pcsx2.nix")
    # Buzz has no upstream Nix packaging, so it is repackaged from the official
    # .deb. Shared rather than host-local because nothing about it is host-specific;
    # only desktop hosts pull env-packages.nix and actually build it.
    (import "${inputs.self}/modules/_features/overlays/buzz-desktop.nix")
    # Kimi Code 0.34.0 (new standalone CLI) — provides bin/kimi and bin/kimi-code.
    (import "${inputs.self}/modules/_features/overlays/kimi-code.nix")
    # CineMaya/Lumen — built from our own source, served from stage-edge.
    # Only that host references lumen-web/lumen-lab, so nothing else builds it.
    (import "${inputs.self}/modules/_features/overlays/lumen.nix")
    # DeepSeek Harness (dsh) — agent harness driving the local LLM router on
    # cerberus. Vendored from the npm release with a committed lock; only
    # cerberus enables the service, so nothing else builds it.
    (import "${inputs.self}/modules/_features/overlays/deepseek-harness.nix")
  ];
}
