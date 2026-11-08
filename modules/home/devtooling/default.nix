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
        my.devtooling.enable = lib.mkEnableOption "Enable devtooling module";
      };
      config = lib.mkIf config.my.devtooling.enable {
        my.git.enable = lib.mkDefault true;
        my.gleam.enable = lib.mkDefault true;
        my.go.enable = lib.mkDefault true;
        my.kubernetes.enable = lib.mkDefault true;
        my.lua.enable = lib.mkDefault true;
        my.pi-agent.enable = lib.mkDefault true;
        my.remmina.enable = lib.mkDefault true;
        my.rust.enable = lib.mkDefault true;
        my.tmux.enable = lib.mkDefault true;
        my.zed.enable = lib.mkDefault true;
      };
    };
}
