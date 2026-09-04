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
        # TODO(unsolved): cache.garnix.io disabled 2026-08-09 — it was timing out
        # entirely (no response to /nix-cache-info), and Nix waits on it before
        # falling through, so every cache miss paid the timeout. Re-enable once it
        # responds again; nothing here depends on it exclusively.
        # "https://cache.garnix.io/"
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
      # 115k .drv files were being retained for no benefit — every derivation
      # here is re-instantiable from the flake, so keeping them only burns
      # inodes and blocks the GC from reclaiming their inputs.
      keep-derivations = false;
      # Let the daemon GC opportunistically mid-build instead of filling / to
      # 100%, which it did twice in Sept 2026. Below 50 GiB free it collects
      # until 200 GiB is free.
      min-free = 53687091200; # 50 GiB
      max-free = 214748364800; # 200 GiB
      trusted-users = [
        "root"
        "franky"
        "@wheel"
      ];
    };
    optimise.automatic = true;
    # NOTE: this prunes *system* generations only. Per-user `nix profile`
    # generations need `nix profile wipe-history`, which nix-collect-garbage
    # cannot do — see modules/_features/nix-user-gc.nix for that half.
    gc = {
      automatic = true;
      dates = "weekly";
      # 7d rather than 3d: the 3d window was never what caused the store to
      # grow (stale gcroots were), and a week of generations is a more useful
      # rollback range.
      options = "--delete-older-than 7d";
    };
  };
}
