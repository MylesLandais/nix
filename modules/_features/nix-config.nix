{ inputs, ... }: {
  nixpkgs.config = {
    allowUnfree = true;
    # electron-39 is EOL but still pulled transitively by desktop apps
    # (e.g. vesktop). Permit until those deps move to a newer electron.
    permittedInsecurePackages = [
      "electron-39.8.10"
      # Build-time tool for vesktop (Discord), not runtime. Permit until nixpkgs ships newer pnpm.
      "pnpm-10.29.2"
    ];
  };
  nix = {
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      # Keep this list in sync with the `nixConfig.extra-substituters` block in
      # flake.nix. Those flake-level entries are silently dropped ("ignoring
      # untrusted flake configuration setting") because the invoking user is not a
      # trusted-user, so a cache declared only there is never actually consulted and
      # its packages get compiled locally instead. noctalia and numtide were in that
      # position — noctalia is a direct input with a bar module, so it was building
      # from source on every bump.
      substituters = [
        "https://nix-community.cachix.org/"
        "https://attic.xuyh0120.win/lantian"
        "https://cache.nixos.org/"
        "https://zed.cachix.org/"
        "https://cache.garnix.io/"
        "https://noctalia.cachix.org"
        "https://cache.numtide.com"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "franky"
        "@wheel"
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };
}
