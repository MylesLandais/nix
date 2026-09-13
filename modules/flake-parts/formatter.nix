# Treefmt / nix fmt wiring. The flakeModule itself is imported in flake.nix
# so systems and the treefmt option are available; this file only configures it.
_: {
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true;
      programs.deadnix.enable = true;
      # Don't strip lambda attrset pattern names; without this deadnix removes
      # intentionally-accepted params like mkHost's `name ? null`, which host
      # files still pass, breaking evaluation with "unexpected argument".
      programs.deadnix.no-lambda-pattern-names = true;
      programs.statix.enable = true;
      settings.global.excludes = [
        "assets/**"
        "ventoy-*/**"
        "windows-kit/**"
      ];
    };
  };
}
