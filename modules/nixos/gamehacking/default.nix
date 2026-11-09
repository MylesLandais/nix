_: {
  flake.modules.nixos.gamehacking =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ ./_citra-agent.nix ];

      options.host.gamehacking.enable = lib.mkEnableOption "game reverse engineering and ROM hacking tools";

      config = lib.mkIf config.host.gamehacking.enable {

        environment.systemPackages = import ./_packages.nix { inherit pkgs; };
      };
    };
}
