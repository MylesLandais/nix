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

  options = {
    bars.enable = lib.mkEnableOption "Enable bars module";
  };

  config = {
    bars = {
      noctalia.enable = lib.mkDefault false;
      hyprpanel.enable = lib.mkDefault false;
      ricelin.enable = lib.mkDefault false;
    };
  };
}
