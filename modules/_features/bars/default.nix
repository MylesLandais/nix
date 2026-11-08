{
  lib,
  ...
}:
{
  imports = [
    ./noctalia.nix
  ];

  config = {
    bars = {
      noctalia.enable = lib.mkDefault false;
    };
  };
}
