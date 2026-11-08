{ inputs, lib }:
let
  inherit (inputs) self;

  baselineModulePaths =
    { desktop }:
    [
      self.modules.nixos.hostOptions
      self.modules.nixos.nixConfig
      self.modules.nixos.fishConfig
      self.modules.nixos.overlays
    ]
    ++ lib.optionals desktop [
      self.modules.nixos.envPackages
    ];

  userHasAgenix = users: lib.any (u: (users.${u}.ageIdentity or null) != null) (lib.attrNames users);

  mkHomeManagerConfig =
    {
      system,
      users,
      extraSpecialArgs ? { },
      backupFileExtension ? null,
    }:
    {
      home-manager = {
        useUserPackages = true;
        useGlobalPkgs = true;
        inherit backupFileExtension;
        sharedModules = lib.optionals (userHasAgenix users) [
          inputs.agenix.homeManagerModules.age
        ];
        users = lib.mapAttrs (
          username: userCfg:
          {
            pkgs,
            ...
          }:
          let
            extra = if userCfg ? extraConfig then userCfg.extraConfig { inherit pkgs; } else { };
            base = {
              imports = userCfg.homeModules or [ ];
              home.username = username;
              home.homeDirectory = "/home/${username}";
            };
            withUid = lib.recursiveUpdate base (
              lib.optionalAttrs (userCfg.uid or null != null) {
                home.uid = userCfg.uid;
              }
            );
            withAge = lib.recursiveUpdate withUid (
              lib.optionalAttrs (userCfg.ageIdentity or null != null) {
                age.identityPaths = [ userCfg.ageIdentity ];
              }
            );
          in
          lib.recursiveUpdate withAge extra
        ) users;
        extraSpecialArgs = {
          inherit inputs;
          inherit system;
        }
        // extraSpecialArgs;
      };
    };

  mkModules =
    {
      modules,
      homeManagerModule ? inputs.home-manager.nixosModules.home-manager,
      users,
      extraSpecialArgs ? { },
      backupFileExtension ? null,
      baseline ? true,
      desktop ? false,
      system ? "x86_64-linux",
    }:
    let
      userNames = lib.attrNames users;
    in
    (lib.optionals baseline (baselineModulePaths {
      inherit desktop;
    }))
    ++ modules
    ++ lib.optionals (userNames != [ ]) [
      homeManagerModule
      (mkHomeManagerConfig {
        inherit
          system
          users
          extraSpecialArgs
          backupFileExtension
          ;
      })
    ];
in
{
  inherit mkModules;

  mkHost =
    {
      # deadnix: skipped via treefmt -L flag (lambda pattern names are not
      # checked); host files still pass `name`, so removing it breaks
      # evaluation with "called with unexpected argument 'name'".
      name ? null,
      system ? "x86_64-linux",
      modules,
      users,
      extraSpecialArgs ? { },
      backupFileExtension ? null,
      specialArgs ? { },
      baseline ? true,
      desktop ? false,
      # nixpkgs and home-manager to build with; 7PZSZY2 uses nixos-wsl's pins.
      nixpkgs ? inputs.nixpkgs,
      homeManagerModule ? inputs.home-manager.nixosModules.home-manager,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = specialArgs // {
        inherit inputs;
      };
      modules = mkModules {
        inherit
          modules
          homeManagerModule
          users
          extraSpecialArgs
          backupFileExtension
          baseline
          desktop
          system
          ;
      };
    };
}
