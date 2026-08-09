_: {
  flake.nixosModules.scbw =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.host.scbw.enable = lib.mkEnableOption "StarCraft: Remastered (Battle.net) and Brood War bot build tooling";

      config = lib.mkIf config.host.scbw.enable {
        nixpkgs.config.allowUnfree = true;

        environment.systemPackages = import ../_features/scbw/packages.nix { inherit pkgs; };
      };
    };
}
