_: {
  flake.nixosModules.gamehacking =
    { config, lib, pkgs, ... }:
    {
      options.host.gamehacking.enable = lib.mkEnableOption "game reverse engineering and ROM hacking tools";

      config = lib.mkIf config.host.gamehacking.enable {
        nixpkgs.config.allowUnfree = true;

        environment.systemPackages = import ../features/gamehacking/packages.nix { inherit pkgs; };
      };
    };
}
