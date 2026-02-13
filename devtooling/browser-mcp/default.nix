{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    browser-mcp.enable = lib.mkEnableOption "Enable browser MCP integration";
  };

  config = lib.mkIf config.browser-mcp.enable {
    # Script to launch Chrome with remote debugging for MCP
    home.file.".local/bin/chrome-with-mcp" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        google-chrome --remote-debugging-port=9222 "$@"
      '';
    };

    # Example MCP configuration for opencode/Claude
    home.file.".config/opencode/mcp-servers.json".text = ''
      {
        "mcpServers": {
          "chrome-devtools": {
            "command": "bunx",
            "args": ["chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"]
          }
        }
      }
    '';
  };
}
