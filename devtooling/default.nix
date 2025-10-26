{
  lib,
  config,
  ...
}:
{
  imports = [
    ./elixir
    ./git
    ./gleam
    ./go
    ./kubernetes
    ./lua
    ./remmina
    ./rust
    ./tmux
    ./zed
  ];

  options = {
    devtooling.enable = lib.mkEnableOption "Enable devtooling module";
  };
  config = lib.mkIf config.devtooling.enable {
    git.enable = lib.mkDefault true;
    go.enable = lib.mkDefault false;
    kubernetes.enable = lib.mkDefault false;
    lua.enable = lib.mkDefault false;
    remmina.enable = lib.mkDefault false;
    rust.enable = lib.mkDefault false;
    tmux.enable = lib.mkDefault false;
    zed.enable = lib.mkDefault true;
  };
}
