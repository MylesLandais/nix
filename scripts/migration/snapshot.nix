# Evaluation half of the migration harness (see docs/migration/README.md).
#
#   import ./snapshot.nix { flakeRef = "git+file:///repo?rev=<sha>"; } -> { meta, flake, host }
#
# `flake` is layer A (structure) plus the non-host part of layer B.
# `host <name>` is layer B (drvPaths) plus layer C (generated artifacts and
# selected evaluated options) for one nixosConfiguration.
#
# Nothing here builds anything: drvPaths and outPaths are computed by
# evaluation only. Every leaf is wrapped in `try`, so an attribute that throws
# shows up as "<eval-error>" in the diff instead of aborting the whole capture.
{ flakeRef }:
let
  flake = builtins.getFlake flakeRef;
  inherit (flake.inputs.nixpkgs) lib;

  hash = builtins.hashString "sha256";
  plain = s: builtins.unsafeDiscardStringContext (toString s);

  try =
    v:
    let
      r = builtins.tryEval (builtins.deepSeq v v);
    in
    if r.success then r.value else "<eval-error>";

  tryHash = v: try (if v == null then null else hash (plain v));

  # toJSON that tolerates functions and derivations: functions become a marker,
  # derivations become their outPath.
  sanitize =
    depth: v:
    if depth > 12 then
      "<too-deep>"
    else if lib.isDerivation v then
      plain v.outPath
    else if lib.isFunction v then
      "<function>"
    else if builtins.isPath v then
      plain v
    else if builtins.isString v then
      plain v
    else if builtins.isList v then
      map (sanitize (depth + 1)) v
    else if builtins.isAttrs v then
      lib.mapAttrs (_: x: try (sanitize (depth + 1) x)) v
    else
      v;
  json = v: try (sanitize 0 v);
  jsonHash = v: try (hash (builtins.toJSON (sanitize 0 v)));

  pkgId = p: {
    name = try (lib.getName p);
    version = try (lib.getVersion p);
    out = try (plain p.outPath);
  };
  pkgIds = ps: try (lib.sort (a: b: a.out < b.out) (map pkgId ps));

  # Systemd unit sets (system or user): what is enabled, what pulls it in, and
  # a hash of the generated unit text.
  units =
    us:
    lib.mapAttrs (
      _: u:
      try {
        enable = u.enable or true;
        wantedBy = lib.sort (a: b: a < b) (u.wantedBy or [ ]);
        requiredBy = lib.sort (a: b: a < b) (u.requiredBy or [ ]);
        text = tryHash (u.text or null);
      }
    ) us;

  # `<ns>.<x>.enable` for every *declared, visible* option under a namespace.
  # Walking config values directly trips renamed/removed option modules, which
  # `abort` (not catchable by tryEval); renames are declared with visible = false.
  enableFlags =
    opts: values:
    lib.mapAttrs (n: _: try values.${n}.enable) (
      lib.filterAttrs (
        _: o:
        let
          r = builtins.tryEval (
            builtins.isAttrs o
            && o ? enable
            && lib.isOption o.enable
            && (o.enable.visible or true) != false
            && o.enable.type.name or "" == "bool"
          );
        in
        r.success && r.value
      ) opts
    );

  # Layer A: output tree, stopping at derivations, functions and depth 3.
  tree =
    depth: v:
    let
      r = builtins.tryEval (
        if lib.isDerivation v then
          "drv"
        else if lib.isFunction v then
          "fn"
        else if builtins.isAttrs v && depth < 3 then
          lib.mapAttrs (_: tree (depth + 1)) v
        else if builtins.isAttrs v then
          "attrs"
        else
          builtins.typeOf v
      );
    in
    if r.success then r.value else "<eval-error>";

  outputsTree =
    lib.mapAttrs
      (
        name: v:
        if
          lib.elem name [
            "nixosConfigurations"
            "nixosModules"
            "homeManagerModules"
            "modules"
            "colmena"
          ]
        then
          # Don't walk into configurations or module values; names are the contract.
          try (
            lib.mapAttrs (_: x: if builtins.isAttrs x && !(x ? _type) then builtins.attrNames x else "leaf") v
          )
        else
          tree 1 v
      )
      (
        removeAttrs flake [
          "inputs"
          "outputs"
          "sourceInfo"
          "outPath"
          "_type"
          "lastModified"
          "lastModifiedDate"
          "narHash"
          "rev"
          "shortRev"
          "revCount"
          "submodules"
        ]
      );

  registry = {
    nixos = try (builtins.attrNames (flake.modules.nixos or { }));
    homeManager = try (builtins.attrNames (flake.modules.homeManager or { }));
    nixosModules = try (builtins.attrNames (flake.nixosModules or { }));
    homeManagerModules = try (builtins.attrNames (flake.homeManagerModules or { }));
  };

  # Layer B, non-host: every packages/devShells drvPath except the host-*
  # packages, which are the toplevels already captured per host.
  drvPathsOf =
    out:
    lib.mapAttrs (
      _: perSys:
      lib.mapAttrs (_: d: try (plain d.drvPath)) (
        lib.filterAttrs (n: _: !(lib.hasPrefix "host-" n)) perSys
      )
    ) (flake.${out} or { });

  hostSnapshot =
    name:
    let
      sys = flake.nixosConfigurations.${name};
      cfg = sys.config;
      hm = cfg.home-manager.users or { };
      hmUser =
        _user: h:
        let
          # HM options for this user, from the submodule's own evaluation.
          hmOpts = sys.options.home-manager.users.type.getSubOptions [ ];
        in
        {
          activationPackage = try (plain h.home.activationPackage.drvPath);
          packages = pkgIds h.home.packages;
          files = lib.mapAttrs (
            _: f:
            try {
              inherit (f) target enable;
              source = plain f.source;
              executable = f.executable or null;
            }
          ) h.home.file;
          sessionVariables = json h.home.sessionVariables;
          activation = lib.mapAttrs (_: a: tryHash (a.data or a)) h.home.activation;
          programs = enableFlags (hmOpts.programs or { }) h.programs;
          services = enableFlags (hmOpts.services or { }) h.services;
          userUnits = jsonHash (h.systemd.user or { });
          windowManager = lib.mapAttrs (_: jsonHash) (h.wayland.windowManager or { });
          username = try h.home.username;
          homeDirectory = try h.home.homeDirectory;
        };
    in
    {
      B = {
        toplevel = try (plain cfg.system.build.toplevel.drvPath);
        homeManager = lib.mapAttrs (_: h: try (plain h.home.activationPackage.drvPath)) hm;
      };
      C = {
        units = units cfg.systemd.units;
        userUnits = units cfg.systemd.user.units;
        activationScripts = lib.mapAttrs (
          _: a: tryHash (if builtins.isString a then a else a.text)
        ) cfg.system.activationScripts;
        etc = lib.mapAttrs (
          _: e:
          try {
            inherit (e) enable target mode;
            source = plain e.source;
          }
        ) cfg.environment.etc;
        systemPackages = pkgIds cfg.environment.systemPackages;
        firewall = json {
          inherit (cfg.networking.firewall)
            enable
            allowedTCPPorts
            allowedUDPPorts
            allowedTCPPortRanges
            allowedUDPPortRanges
            trustedInterfaces
            interfaces
            allowPing
            checkReversePath
            ;
          extraCommands = tryHash (cfg.networking.firewall.extraCommands or "");
        };
        networking = json {
          inherit (cfg.networking) hostName domain nameservers;
          interfaces = builtins.attrNames cfg.networking.interfaces;
          networkmanager = cfg.networking.networkmanager.enable;
          useDHCP = cfg.networking.useDHCP;
        };
        users = lib.mapAttrs (
          _: u:
          try {
            inherit (u)
              uid
              isNormalUser
              isSystemUser
              group
              home
              createHome
              ;
            extraGroups = lib.sort (a: b: a < b) u.extraGroups;
            shell = plain (if u.shell == null then "" else u.shell);
            # Presence and hash only; never the value.
            hashedPassword = tryHash u.hashedPassword;
            initialPassword = tryHash u.initialPassword;
            authorizedKeys = jsonHash u.openssh.authorizedKeys.keys;
          }
        ) cfg.users.users;
        groups = lib.mapAttrs (
          _: g:
          try {
            inherit (g) gid;
            members = lib.sort (a: b: a < b) g.members;
          }
        ) cfg.users.groups;
        nixSettings = json cfg.nix.settings;
        nixpkgsConfig = json {
          allowUnfree = cfg.nixpkgs.config.allowUnfree or null;
          permittedInsecurePackages = cfg.nixpkgs.config.permittedInsecurePackages or null;
          overlays = builtins.length cfg.nixpkgs.overlays;
        };
        fileSystems = lib.mapAttrs (
          _: f:
          try {
            inherit (f) device fsType;
            inherit (f) options;
          }
        ) cfg.fileSystems;
        swapDevices = json cfg.swapDevices;
        session = json {
          displayManager = {
            defaultSession = cfg.services.displayManager.defaultSession or null;
            autoLogin = cfg.services.displayManager.autoLogin or null;
            sddm = cfg.services.displayManager.sddm.enable or null;
            gdm = cfg.services.displayManager.gdm.enable or null;
          };
          greetd = cfg.services.greetd.enable or null;
          xserver = cfg.services.xserver.enable or null;
        };
        programs = enableFlags sys.options.programs cfg.programs;
        services = enableFlags sys.options.services cfg.services;
        # The repo's own option namespace; captured whole.
        host = json (cfg.host or null);
        wsl = json (cfg.wsl or null);
        homeManager = lib.mapAttrs hmUser hm;
        homeManagerSettings = json {
          useGlobalPkgs = cfg.home-manager.useGlobalPkgs or null;
          useUserPackages = cfg.home-manager.useUserPackages or null;
          backupFileExtension = cfg.home-manager.backupFileExtension or null;
        };
      };
    };
in
{
  meta = {
    rev = flake.sourceInfo.rev or null;
    dirtyRev = flake.sourceInfo.dirtyRev or null;
    hosts = builtins.attrNames (flake.nixosConfigurations or { });
  };

  flake = {
    A = {
      outputs = outputsTree;
      inherit registry;
    };
    B = {
      packages = drvPathsOf "packages";
      devShells = drvPathsOf "devShells";
    };
  };

  host = hostSnapshot;
}
