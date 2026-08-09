# Treefmt / nix fmt wiring. The flakeModule itself is imported in flake.nix
# so systems and the treefmt option are available; this file only configures it.
_: {
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true;
      programs.deadnix.enable = true;
      programs.statix.enable = true;
      settings.global.excludes = [
        "assets/**"
        "ventoy-*/**"
        "windows-kit/**"
      ];
    };
  };
}
