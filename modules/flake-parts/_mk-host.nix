{ inputs, lib }:
let
  inherit (inputs) self;

  baselineModulePaths =
    { desktop }:
    [
      "${self}/modules/_features/host-options.nix"
      "${self}/modules/_features/nix-config.nix"
      "${self}/modules/_features/fish-config.nix"
      "${self}/modules/_features/overlays.nix"
    ]
    ++ lib.optionals desktop [
      "${self}/modules/_features/env-packages.nix"
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
      inputs.home-manager.nixosModules.home-manager
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
      # Optional label for callers; unused by nixosSystem (attr name is set by the host file).
      # deadnix: skip — deliberately accepted-and-ignored. `nix fmt` runs deadnix,
      # which strips this as unused; host files still pass `name`, so removing it
      # breaks evaluation with "called with unexpected argument 'name'".
      name ? null,
      system ? "x86_64-linux",
      modules,
      users,
      extraSpecialArgs ? { },
      backupFileExtension ? null,
      specialArgs ? { },
      baseline ? true,
      desktop ? false,
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = specialArgs // {
        inherit inputs;
      };
      modules = mkModules {
        inherit
          modules
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
