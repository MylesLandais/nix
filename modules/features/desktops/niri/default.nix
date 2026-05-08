{
  lib,
  config,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    inputs.niri.homeModules.niri
    inputs.niri.homeModules.stylix
    ./niri.nix
  ];

  options = {
    niri.enable = lib.mkEnableOption "Enable niri module";
  };

  config = lib.mkIf (config.niri.enable && osConfig.host.desktop == "niri") {
    niriConfig.enable = lib.mkDefault true;

    bars = {
      noctalia.enable = lib.mkIf (osConfig.host.bar == "noctalia") true;
      caelestia.enable = lib.mkIf (osConfig.host.bar == "caelestia") true;
    };
  };
}
