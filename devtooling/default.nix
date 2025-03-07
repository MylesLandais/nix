{
  lib,
  config,
  ...
}:
{
  imports = [
    ./git
    ./gleam
    ./go
    ./kubernetes
    ./lua
    ./rust
    ./tmux
  ];

  options = {
    devtooling.enable = lib.mkEnableOption "Enable devtooling module";
  };
  config = lib.mkIf config.devtooling.enable {
    git.enable = lib.mkDefault true;
    gleam.enable = lib.mkDefault true;
    go.enable = lib.mkDefault true;
    kubernetes.enable = lib.mkDefault true;
    lua.enable = lib.mkDefault true;
    rust.enable = lib.mkDefault true;
    tmux.enable = lib.mkDefault true;
  };
}
