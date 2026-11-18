# Shared nixpkgs overlays required by modules consumed across hosts
# (e.g. homeManager.firefox needs pkgs.nur). Host-specific overlays
# (CachyOS kernel, cursor AppImage pin) stay on the host module.
_: {
  flake.modules.nixos.overlays =
    { inputs, ... }:
    {
      nixpkgs.overlays = [
        inputs.nur.overlays.default
        # Custom packages from pkgs/ (claude-code, buzz-desktop, kimi-code,
        # deepseek-harness); see modules/flake/packages.nix.
        inputs.self.overlays.default
        inputs.nix-vscode-extensions.overlays.default
        # Stable PCSX2 fast-path: reuse nixpkgs' build recipe while pinning the
        # immutable upstream release and patches snapshot locally.
        (import ./_pcsx2.nix)
      ];
    };
}
