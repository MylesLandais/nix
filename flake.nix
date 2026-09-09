{
  nixConfig = {

    extra-substituters = [
      "https://nix-community.cachix.org/"
      "https://attic.xuyh0120.win/lantian"
      "https://cache.nixos.org/"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
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
    agenix.url = "github:ryantm/agenix";
    # Declarative partitioning for the OCI aarch64 hosts (stage-edge, stage-db).
    # These are installed with nixos-anywhere, which wipes and repartitions the
    # Oracle boot volume from the disko config rather than reusing Oracle's LVM layout.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    sunshine-nixpkgs.url = "github:NixOS/nixpkgs/f13ff45afd1bb73e640eaa08a7066dbed07e3238";
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.8.31";
    nur.url = "github:nix-community/NUR";
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # numtide multi-agent flake: opencode, codex, gemini-cli, etc. Tracks
    # upstream agent releases — `nix flake update llm` keeps them all current.
    llm = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    thorium = {
      url = "github:Rishabh5321/thorium_flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      # Held at this rev: newer noctalia-shell restructured its home-manager
      # module (dropped `programs.noctalia-shell` + the noctalia-qs input),
      # which breaks modules/_features/bars/noctalia.nix. Bump intentionally
      # once that module is migrated to the new API.
      url = "github:noctalia-dev/noctalia-shell/b16dc50250af05d5048ac454dbf4e898d1adcac0";
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
    # TODO(unsolved): held at the 2026-07-10 rev. The 2026-08-09 update pointed at
    # zen release 1.21.13b, whose GitHub asset 404s —
    # https://github.com/zen-browser/desktop/releases/download/1.21.13b/zen.linux-x86_64.tar.xz
    # returns 404, so the fetch fails and the whole toplevel build fails with it.
    # Upstream packaging bug, nothing to fix on our side.
    # To resolve: drop the pin back to the bare URL once upstream publishes a release
    # whose asset actually exists.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/71e156423dae9496d7fd9e89029a1a82516fb9d8";
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
    (flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.modules
        inputs.treefmt-nix.flakeModule
        (import-tree ./modules)
      ];
      systems = [ "x86_64-linux" ];
    })
    // {
      devShells = inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = import inputs.nixpkgs { inherit system; };
        in
        {
          forgejo = pkgs.mkShell {
            packages = with pkgs; [
              opentofu
              docker-compose
              openssl
              jq
              postgresql_16
              skopeo
            ];
          };
        }
      );
    };
}
