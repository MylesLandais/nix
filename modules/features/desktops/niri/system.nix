{
  lib,
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.niri.nixosModules.niri ];

  config = lib.mkIf (config.host.desktop == "niri") {
    programs.niri.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
