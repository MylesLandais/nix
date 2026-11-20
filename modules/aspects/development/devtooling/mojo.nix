# Mojo toolchain plus its Claude Code LSP wiring.
#
# Claude Code has no official Mojo LSP plugin, so this ships the language
# server that comes with the toolchain (mojo-lsp-server) and a local plugin
# that exposes it:
#
#   ~/.claude-plugins/mojo-lsp/.claude-plugin/plugin.json
#   ~/.claude-plugins/mojo-lsp/.lsp.json
#
# The plugin directory doubles as a local marketplace; register it once so no
# per-session --plugin-dir is needed:
#
#   claude plugin marketplace add ~/.claude-plugins/mojo-lsp
#   claude plugin install mojo-lsp@mojo-lsp
#
# mojo-bin is Modular's prebuilt toolchain (unfree). nixpkgs applies
# autoPatchelf, so it runs without nix-ld; it does require an x86-64-v3 CPU
# (avx2, satisfied on this host).
{ inputs, lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1150 {
    imports = [
      (
        {
          pkgs,
          lib,
          config,
          ...
        }:
        let
          # mojo-bin comes from the frozen mojo-nixpkgs pin (see flake.nix).
          # Direct legacyPackages access would evaluate without the repo's
          # allowUnfree config, so import the pin like sunshine.nix does.
          mojoNixpkgs = import inputs.mojo-nixpkgs {
            inherit (pkgs) system;
            config.allowUnfree = true;
          };
        in
        {
          options = {
            my.mojo.enable = lib.mkEnableOption "Enable mojo module";
          };
          config = lib.mkIf config.my.mojo.enable {
            home.packages = [
              mojoNixpkgs.mojo-bin
            ];

            home.file = {
              ".claude-plugins/mojo-lsp/.claude-plugin/plugin.json".text = builtins.toJSON {
                name = "mojo-lsp";
                version = "1.0.0";
                description = "Mojo language server (mojo-lsp-server) for Claude Code";
              };
              ".claude-plugins/mojo-lsp/.lsp.json".text = builtins.toJSON {
                mojo = {
                  command = "mojo-lsp-server";
                  extensionToLanguage = {
                    ".mojo" = "mojo";
                    ".🔥" = "mojo";
                  };
                };
              };
              ".claude-plugins/mojo-lsp/.claude-plugin/marketplace.json".text = builtins.toJSON {
                name = "mojo-lsp";
                owner.name = "warby";
                plugins = [
                  {
                    name = "mojo-lsp";
                    source = "./";
                    description = "Mojo language server (mojo-lsp-server) for Claude Code";
                  }
                ];
              };
            };
          };
        }
      )
    ];
  };
}
