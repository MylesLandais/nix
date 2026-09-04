_: {
  flake.nixosModules.gamehacking =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ../_features/citra-agent.nix ];

      options.host.gamehacking.enable = lib.mkEnableOption "game reverse engineering and ROM hacking tools";

      config = lib.mkIf config.host.gamehacking.enable {
        nixpkgs.config.allowUnfree = true;

        environment.systemPackages = import ../_features/gamehacking/packages.nix { inherit pkgs; };
      };
    };
}
