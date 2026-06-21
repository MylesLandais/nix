{
  nixConfig = {

    extra-substituters = [
      "https://nix-community.cachix.org/"
      "https://attic.xuyh0120.win/lantian"
      "https://cache.nixos.org/"
      "https://noctalia.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    # Held at this rev: newer nixvim dropped `programs.nixvim.cmp`, which the
    # pinned frostvim modules still set. Bump together with frostvim once they
    # are compatible again.
    nixvim.url = "github:nix-community/nixvim/e5c7b40dc569f5c97ba2182d409f0fb54c02d7c1";
    frostvim.url = "github:FKouhai/frostvim";
    helium.url = "github:FKouhai/helium2nix";
    agenix.url = "github:ryantm/agenix";
    trigo.url = "github:FKouhai/trigo";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    hermes-agent.url = "github:NousResearch/hermes-agent/v2026.6.19";
    nur.url = "github:nix-community/NUR";
    claude-code.url = "github:sadjow/claude-code-nix";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
    };
    codex-nix.url = "github:SecBear/codex-nix";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cursor-flake = {
      url = "github:omarcresp/cursor-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    thorium.url = "github:Rishabh5321/thorium_flake";
    noctalia = {
      # Held at this rev: newer noctalia-shell restructured its home-manager
      # module (dropped `programs.noctalia-shell` + the noctalia-qs input),
      # which breaks modules/features/bars/noctalia.nix. Bump intentionally
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
    opencode = {
      # Held at this rev: opencode 1.17.7 requires bun@^1.3.14 but the pinned
      # nixpkgs only has bun 1.3.13, so the build fails. Bump once nixpkgs
      # catches up to bun >= 1.3.14.
      url = "github:anomalyco/opencode/c48000655458bf1317314413259808b8f8293dd0";
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
  };

  outputs =
    inputs@{ flake-parts, import-tree, ... }:
    (flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        (import-tree ./modules/hosts)
        (import-tree ./modules/services)
        (import-tree ./modules/flake-parts)
      ];
      systems = [ "x86_64-linux" ];
    })
    // {
      colmena = import ./colmena.nix { inherit inputs; };
    };
}
