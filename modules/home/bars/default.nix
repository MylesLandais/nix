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
        my.bars = {
          noctalia.enable = lib.mkDefault false;
        };
      };
    };
}
