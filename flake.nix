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
    import-tree.url = "github:vic/import-tree";
    helium.url = "github:FKouhai/helium2nix";
    agenix.url = "github:ryantm/agenix";
    trigo.url = "github:FKouhai/trigo";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.6.19";
    nur.url = "github:nix-community/NUR";
    claude-code.url = "github:sadjow/claude-code-nix";
    # numtide multi-agent flake: opencode, codex, gemini-cli, etc. Tracks
    # upstream agent releases — `nix flake update llm` keeps them all current.
    llm.url = "github:numtide/llm-agents.nix";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
    };
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    thorium.url = "github:Rishabh5321/thorium_flake";
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
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    wallpapers = {
      url = "github:FKouhai/Kanagawa-wallpapers";
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
        inputs.treefmt-nix.flakeModule
        (import-tree ./modules)
      ];
      systems = [ "x86_64-linux" ];
    })
    // {
      colmena = import ./colmena.nix { inherit inputs; };
    };
}
