{
  nixConfig = {

    extra-substituters = [
      "https://nix-community.cachix.org/"
      "https://cache.nixos.org?priority=10"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
    };
    home-manager-wsl = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixos-wsl/nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    helium = {
      url = "github:FKouhai/helium2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Legacy AGS and the findiso installer require this nixpkgs revision.
    installer-compat.url = "github:NixOS/nixpkgs/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8";
    agenix.url = "github:ryantm/agenix";
    # Source-only tracking: upstream ships no flake. The NixOS module in
    # modules/nixos/gpu-unlock.nix consumes `inputs.gpu-unlock` directly and
    # builds the kernel module and firmware from it. `nix flake update
    # gpu-unlock` advances the source pin to upstream's default branch.
    gpu-unlock = {
      url = "github:Zagitta/gpu-unlock";
      flake = false;
    };
    nebula-infra.url = "git+https://git.nebula-1.com/nebula/infra.git?ref=main";
    trigo = {
      url = "github:FKouhai/trigo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Frozen nixpkgs for sunshine only. sunshine is built with cudaSupport = true,
    # a non-default variant Hydra never builds — and CUDA is unfree, so it could not
    # redistribute it anyway. Tracking the main nixpkgs meant every routine bump
    # invalidated it and forced a local CUDA build. Pinned here so ordinary updates
    # leave it alone; bump deliberately when you actually want a newer sunshine.
    # Must stay a fixed rev — a second moving branch would recreate the problem.
    sunshine-nixpkgs.url = "github:NixOS/nixpkgs/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55";
    # Frozen nixpkgs for mojo-bin only. The prebuilt Modular toolchain landed in
    # nixpkgs after the main pin (2026-09-25), and its wheels are unfree binary
    # blobs Hydra does cache, so this pin exists solely to unlock it without
    # dragging the whole main pin forward. Bump deliberately, like sunshine-nixpkgs.
    mojo-nixpkgs.url = "github:NixOS/nixpkgs/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55";
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned to a release tag on purpose — upstream treats Nix as best-effort, so a
    # reproducible tag beats tracking main. Note a tag pin cannot be advanced by
    # `nix flake update`; bump this line to move it.
    #
    # Deliberately does NOT follow nixpkgs. Every other input here does, to keep
    # one glibc/llvm/coreutils in the closure, but hermes-agent's tag is only
    # cached against its own pin: adding `follows` puts 934 derivations
    # (nodejs + electron + the whole npm tree) into a local build. A duplicated
    # closure is cheaper than that compile.
    hermes-agent.url = "github:NousResearch/hermes-agent/v0.23.2";
    nur.url = "github:nix-community/NUR";
    # numtide multi-agent flake: opencode, codex, gemini-cli, etc. Tracks
    # upstream agent releases — `nix flake update llm` keeps them all current.
    #
    # Deliberately does NOT follow nixpkgs. Numtide's binary cache
    # (cache.numtide.com) is built against its own pinned nixpkgs. Setting
    # `follows` invalidates the cache and forces a ~50-minute local Cargo
    # compile of codex from source. A duplicated closure is far cheaper.
    llm.url = "github:numtide/llm-agents.nix";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tokyonight.url = "github:mrjones2014/tokyonight.nix";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The former missing-release-asset hold was resolved by Zen 1.22.1b.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wallpapers = {
      url = "github:FKouhai/Kanagawa-wallpapers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.treefmt-nix.flakeModule
        (import-tree ./modules)
      ];
      systems = [ "x86_64-linux" ];
    };
}
