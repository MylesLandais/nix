{ inputs, lib, ... }:
let
  pkgsForVars = import inputs.nixos-wsl.inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  vars = import "${inputs.self}/vars.nix" { pkgs = pkgsForVars; };
in
{
  flake.nixosConfigurations."7PZSZY2" = inputs.nixos-wsl.inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.self.nixosModules."7PZSZY2"
      "${inputs.self}/modules/features/wsl-agent.nix"
      "${inputs.self}/modules/features/fish-config.nix"
      "${inputs.self}/modules/features/ssh-keys.nix"
      inputs.home-manager-wsl.nixosModules.home-manager
      {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          users.warby =
            { pkgs, ... }:
            {
              imports = [ "${inputs.self}/devtooling/default.nix" ];
              home.username = lib.mkForce "warby";
              home.homeDirectory = lib.mkForce "/home/warby";
              home.stateVersion = "26.05";
              programs.home-manager.enable = true;
              programs.btop = {
                enable = true;
                settings.theme_background = false;
              };

              # Keep the WSL profile headless. Windows supplies Chrome and GUI
              # editors; WSL supplies the coding agents and persistent shells.
              devtooling.enable = true;
              browser-mcp.enable = false;
              code.enable = false;
              cursor.enable = false;
              remmina.enable = false;
              zed.enable = false;
              tmux.enable = true;

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
            };
          extraSpecialArgs = {
            inherit inputs vars;
            system = "x86_64-linux";
          };
        };
      }
    ];
  };
}
