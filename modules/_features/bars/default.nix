{
  lib,
  ...
}:
{
  imports = [
    ./noctalia.nix
    ./hyprpanel.nix
    ./ricelin.nix
  ];

  config = {
    bars = {
      noctalia.enable = lib.mkDefault false;
      hyprpanel.enable = lib.mkDefault false;
      ricelin.enable = lib.mkDefault false;
    };
  };
}
