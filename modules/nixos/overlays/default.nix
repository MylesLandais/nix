# Shared nixpkgs overlays required by modules consumed across hosts
# (e.g. modules/firefox.nix needs pkgs.nur). Host-specific overlays
# (CachyOS kernel, cursor AppImage pin) stay on the host module.
_: {
  flake.modules.nixos.overlays =
    { inputs, ... }:
    {
      nixpkgs.overlays = [
        inputs.nur.overlays.default
        (import ./_claude-code.nix)
        inputs.nix-vscode-extensions.overlays.default
        # Stable PCSX2 fast-path: reuse nixpkgs' build recipe while pinning the
        # immutable upstream release and patches snapshot locally.
        (import ./_pcsx2.nix)
        # Buzz has no upstream Nix packaging, so it is repackaged from the official
        # .deb. Shared rather than host-local because nothing about it is host-specific;
        # only desktop hosts pull env-packages.nix and actually build it.
        (import ./_buzz-desktop.nix)
        # Kimi Code (standalone CLI) — provides bin/kimi and bin/kimi-code.
        (import ./_kimi-code.nix)
        # DeepSeek Harness (dsh) — agent harness driving the local LLM router on
        # cerberus. Vendored from the npm release with a committed lock; only
        # cerberus enables the service, so nothing else builds it.
        (import ./_deepseek-harness.nix)
      ];
    };
}
