_: {
  flake.modules.homeManager.bars =
    {
      lib,
      ...
    }:
    {
      imports = [
        ./_noctalia.nix
      ];

      config = {
        bars = {
          noctalia.enable = lib.mkDefault false;
        };
      };
    };
}
