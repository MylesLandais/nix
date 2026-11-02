# Coordinated Penpot MCP for every local agent harness.
#
# The isolated browser worker holds the remote MCP credential in the keyring:
# Legacy direct credentials can be provisioned with:
#   secret-tool store --label="Penpot MCP" service penpot-mcp username warby
# `penpot-mcp` exposes only coordinated design tools through the local Rust
# gateway. Agent clients never receive the worker token or raw execute_code.
#
# Registration is a script, not a home.activation block: Hermes, Codex and
# Claude keep their MCP lists in live user files, and activation must not touch
# the keyring or block login (CONTRIBUTING §9). Run `penpot-mcp-register` once,
# and again after wiping any of those configs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Stable across rebuilds, unlike the store path, so live configs never go stale.
  bridge = "/etc/profiles/per-user/${config.home.username}/bin/penpot-mcp";

  penpot-mcp = pkgs.writeShellApplication {
    name = "penpot-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      if test -r "${config.xdg.configHome}/nebula/penpot-design-session.env"; then
        # shellcheck source=/dev/null
        source "${config.xdg.configHome}/nebula/penpot-design-session.env"
      fi
      source_root="''${PENPOT_WORKSPACE:-${config.home.homeDirectory}/Workspace}"
      exec node "$source_root/apps/browser-worker/src/penpot/bridge.mjs"
    '';
  };

  penpot-mcp-register = pkgs.writeShellApplication {
    name = "penpot-mcp-register";
    text = ''
      # Each harness: drop any previous entry (Hermes still had a URL entry with
      # an inline token from the retired cerberus stack), then add the bridge.
      if command -v hermes >/dev/null; then
        hermes mcp remove penpot >/dev/null 2>&1 || true
        hermes mcp add penpot --command ${bridge}
      fi
      if command -v codex >/dev/null; then
        codex mcp remove penpot >/dev/null 2>&1 || true
        codex mcp add penpot -- ${bridge}
      fi
      if command -v claude >/dev/null; then
        claude mcp remove --scope user penpot >/dev/null 2>&1 || true
        claude mcp add --scope user penpot -- ${bridge}
      fi
      echo "Registered ${bridge} with hermes, codex and claude. Restart hermes: systemctl --user restart hermes-agent hermes-backend"
    '';
  };
in
{
  home.packages = [
    penpot-mcp
    penpot-mcp-register
  ];

  # Zed's settings are merged from Nix, so it gets the bridge declaratively.
  programs.zed-editor.userSettings.context_servers.penpot = lib.mkIf config.zed.enable {
    source = "custom";
    command = bridge;
    args = [ ];
  };

  # opencode reads ~/.config/opencode/opencode.jsonc (live, user-edited);
  # penpot-mcp-register does not touch it. Its entry, added by hand once:
  #   "mcp": { "penpot": { "type": "local", "command": ["<bridge>"] } }
}
