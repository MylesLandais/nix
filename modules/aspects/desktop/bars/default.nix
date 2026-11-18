_: {
  flake.modules.homeManager.bars =
    {
      lib,
      ...
    }:
    {

      config = {
        my.bars = {
          noctalia.enable = lib.mkDefault false;
        };
      };
    };
}
