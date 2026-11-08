_: {
  flake.modules.homeManager.devtooling =
    {
      lib,
      config,
      ...
    }:
    {
      imports = [
        ./_git
        ./_gleam
        ./_go
        ./_kubernetes
        ./_lua
        ./_pi
        ./_remmina
        ./_rust
        ./_tmux
        ./_zed
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
        pi-agent.enable = lib.mkDefault true;
        remmina.enable = lib.mkDefault true;
        rust.enable = lib.mkDefault true;
        tmux.enable = lib.mkDefault true;
        zed.enable = lib.mkDefault true;
      };
    };
}
