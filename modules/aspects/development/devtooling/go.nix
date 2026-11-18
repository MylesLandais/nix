{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1070 {
    imports = [
      (
        {
          pkgs,
          lib,
          config,
          ...
        }:
        {
          options = {
            my.go.enable = lib.mkEnableOption "Enable go module";
          };
          config = lib.mkIf config.my.go.enable {
            home.packages = with pkgs; [
              go
              gotestsum
              mockgen
              gofumpt
              golines
              govulncheck
              gomodifytags
              gotools
              gotests
              iferr
              delve
              richgo
              impl
              golangci-lint
            ];
          };
        }
      )
    ];
  };
}
