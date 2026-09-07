{ config, lib, pkgs, ... }:
let
  server = "${config.home.homeDirectory}/.local/bin/blender-mcp";
  startup = pkgs.writeText "blender-mcp-start.py" ''
    import bpy
    import addon_utils
    module = "bl_ext.user_default.mcp"
    addon_utils.enable(module, default_set=True, persistent=True)
    prefs = bpy.context.preferences.addons[module].preferences
    prefs.host = "127.0.0.1"
    prefs.port = 9876
    prefs.use_autostart = True
    bpy.ops.wm.save_userpref()
    bpy.ops.blmcp.server_start()
  '';
in
{
  # Blender Lab server and extension are installed separately; see Vault/blender-mcp.md.
  home.activation.blenderMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x ${lib.escapeShellArg server} ]; then
      run ${config.home.path}/bin/codex mcp add blender -- ${lib.escapeShellArg server}
    else
      echo "Blender MCP: install ${server} (see Vault/blender-mcp.md)" >&2
    fi
  '';
  home.packages = [
    (pkgs.writeShellScriptBin "blender-mcp-open" ''
      exec ${pkgs.blender}/bin/blender --online-mode "$@" --python ${startup}
    '')
  ];
}
