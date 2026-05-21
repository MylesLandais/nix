{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  options = {
    go.enable = lib.mkEnableOption "Enable go module";
  };
  config = lib.mkIf config.go.enable {
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
