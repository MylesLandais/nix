_: {
  flake.nixosModules.warcraft3 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.host.warcraft3;
      packageGroups = import ../_features/scbw/packages.nix { inherit pkgs; };

      warcraft3Reforged = import ../_features/battlenet-game.nix { inherit pkgs lib; } {
        name = "Warcraft III: Reforged";
        gameSlug = "warcraft-iii-reforged";
        launchCode = "W3";
        command = "warcraft3-reforged";
        aliases = [ "wc3" ];
        inherit (cfg) prefixDir;
        registrationGlob = "*warcraft*iii*reforged*.yml";
        comment = "Install or launch Warcraft III: Reforged through Battle.net";
        keywords = [
          "Warcraft"
          "Reforged"
          "Battle.net"
        ];
        startupWMClass = "Warcraft III.exe";
      };
    in
    {
      options.host.warcraft3 = {
        enable = lib.mkEnableOption "Warcraft III: Reforged through Battle.net and Lutris";

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/Games/battlenet";
          description = ''
            Mutable Battle.net Wine prefix used by Lutris. Defaults to the
            prefix shared with StarCraft: Remastered, so both games use one
            Battle.net client and one login.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = lib.hasPrefix "/" cfg.prefixDir;
            message = "host.warcraft3.prefixDir must be an absolute path";
          }
        ];

        nixpkgs.config.allowUnfree = true;

        environment.systemPackages = packageGroups.runtime ++ [
          warcraft3Reforged.package
          warcraft3Reforged.desktop
        ];
      };
    };
}
