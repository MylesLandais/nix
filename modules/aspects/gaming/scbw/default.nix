_: {
  flake.modules.nixos.scbw =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.host.scbw;
      packageGroups = import ./_packages.nix { inherit pkgs; };

      starcraftRemastered = import ./_battlenet-game.nix { inherit pkgs lib; } {
        name = "StarCraft: Remastered";
        gameSlug = "starcraft-remastered";
        launchCode = "S1";
        command = "starcraft-remastered";
        aliases = [ "scbw" ];
        inherit (cfg) prefixDir;
        registrationGlob = "*starcraft*remastered*.yml";
        comment = "Install or launch StarCraft: Remastered through Battle.net";
        keywords = [
          "StarCraft"
          "Brood War"
          "Battle.net"
        ];
        startupWMClass = "StarCraft.exe";
      };
    in
    {
      options.host.scbw = {
        enable = lib.mkEnableOption "StarCraft: Remastered through Battle.net and Lutris";

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.users.users.${config.host.username}.home}/Games/battlenet";
          defaultText = lib.literalExpression ''"''${config.users.users.''${config.host.username}.home}/Games/battlenet"'';
          description = "Mutable shared Battle.net Wine prefix used by Lutris.";
        };

        botDev.enable = lib.mkEnableOption "classic Brood War 1.16.1 OpenBW/BWAPI build tooling";
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = lib.hasPrefix "/" cfg.prefixDir;
            message = "host.scbw.prefixDir must be an absolute path";
          }
        ];

        environment.systemPackages =
          packageGroups.runtime
          ++ [
            starcraftRemastered.package
            starcraftRemastered.desktop
          ]
          ++ lib.optionals cfg.botDev.enable packageGroups.botDev;
      };
    };
}
