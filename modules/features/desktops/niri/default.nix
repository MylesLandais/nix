{
  lib,
  osConfig,
  inputs,
  ...
}:
{
  imports = lib.optionals (osConfig.host.desktop == "niri") [
    inputs.niri.homeModules.niri
    ./niri.nix
  ];

  options.niri.enable = lib.mkEnableOption "Enable niri module";
}
