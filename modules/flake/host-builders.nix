{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
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
    homeSettings:
    {
      users,
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
      }
      // homeSettings;
    };

  mkModules =
    forExternalCaller:
    {
      modules,
      homeManagerModule ? inputs.home-manager.nixosModules.home-manager,
      users,
      extraSpecialArgs ? { }, # Public mkModules accepts caller-supplied Home Manager values.
      system ? "x86_64-linux",
      backupFileExtension ? null,
      baseline ? true,
      desktop ? false,
    }:
    let
      userNames = lib.attrNames users;
      homeSettings = lib.optionalAttrs forExternalCaller {
        extraSpecialArgs = {
          inherit inputs system;
        }
        // extraSpecialArgs;
      };
    in
    (lib.optionals baseline (baselineModulePaths {
      inherit desktop;
    }))
    ++ modules
    ++ lib.optionals (userNames != [ ]) [
      homeManagerModule
      (mkHomeManagerConfig homeSettings {
        inherit
          users
          backupFileExtension
          ;
      })
    ];
  mkHost =
    forExternalCaller:
    args@{
      # deadnix: skipped via treefmt -L flag (lambda pattern names are not
      # checked); host files still pass `name`, so removing it breaks
      # evaluation with "called with unexpected argument 'name'".
      name ? null,
      system ? "x86_64-linux",
      modules,
      users,
      specialArgs ? { },
      extraSpecialArgs ? { }, # The published host constructor accepts both module classes.
      backupFileExtension ? null,
      baseline ? true,
      desktop ? false,
      # nixpkgs and home-manager to build with; 7PZSZY2 uses nixos-wsl's pins.
      nixpkgs ? inputs.nixpkgs,
      homeManagerModule ? inputs.home-manager.nixosModules.home-manager,
    }:
    let
      compose = mkModules forExternalCaller;
      callerArgs = specialArgs // {
        inherit inputs;
      };
    in
    nixpkgs.lib.nixosSystem (
      {
        inherit system;
        modules = compose (builtins.intersectAttrs (builtins.functionArgs compose) args);
      }
      // lib.optionalAttrs forExternalCaller {
        specialArgs = callerArgs;
      }
    );
in
{
  options.nodeBuilders = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.addCheck lib.types.raw lib.isFunction);
    internal = true;
    description = "Host and module builders used by this repository.";
  };
  config = {
    nodeBuilders = {
      mkHost = mkHost false;
      mkModules = mkModules false;
    };
    # Other flakes may pass modules that request their own arguments.
    flake.lib = {
      mkHost = mkHost true;
      mkModules = mkModules true;
    };
  };
}
