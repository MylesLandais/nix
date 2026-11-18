# The sibling module priorities retain the original import order and configuration precedence.
_: {
  flake.modules.nixos.gamehacking =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {

      options.host.gamehacking.enable = lib.mkEnableOption "game reverse engineering and ROM hacking tools";

      config = lib.mkIf config.host.gamehacking.enable {

        environment.systemPackages = import ./_packages.nix { inherit pkgs; };
      };
    };
}
