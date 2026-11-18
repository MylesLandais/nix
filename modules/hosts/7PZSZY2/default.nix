{ config, inputs, ... }:
{
  # WSL host: built against nixos-wsl's nixpkgs and home-manager pins, and
  # without the desktop baseline (only fish config and SSH keys).
  flake.nixosConfigurations."7PZSZY2" = config.nodeBuilders.mkHost {
    name = "7PZSZY2";
    nixpkgs = inputs.nixos-wsl.inputs.nixpkgs;
    homeManagerModule = inputs.home-manager-wsl.nixosModules.home-manager;
    baseline = false;
    modules = [
      inputs.self.modules.nixos."7PZSZY2"
      inputs.self.modules.nixos.wslAgent
      inputs.self.modules.nixos.fishConfig
      inputs.self.modules.nixos.sshKeys
    ];
    users.warby.homeModules = [
      (
        { pkgs, ... }:
        {
          imports = [ inputs.self.modules.homeManager.devtooling ];
          home.stateVersion = "26.05";
          programs.home-manager.enable = true;
          programs.btop = {
            enable = true;
            settings.theme_background = false;
          };

          # Keep the WSL profile headless. Windows supplies Chrome and GUI
          # editors; WSL supplies the coding agents and persistent shells.
          my.devtooling.enable = true;
          my.remmina.enable = false;
          my.zed.enable = false;
          # The shared themed tmux profile requires desktop host options.
          my.tmux.enable = false;
          programs.tmux = {
            enable = true;
            keyMode = "vi";
            shortcut = "a";
          };

          home.file.".config/opencode/mcp-servers.json".text = builtins.toJSON {
            mcpServers.chrome-devtools = {
              command = "bunx";
              args = [
                "chrome-devtools-mcp@latest"
                "--browserUrl=http://127.0.0.1:9222"
              ];
            };
          };

          home.packages = with pkgs; [
            eza
            zoxide
            fzf
            bat
          ];
        }
      )
    ];
  };
}
