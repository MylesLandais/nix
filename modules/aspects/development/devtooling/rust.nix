{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1120 {
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
            my.rust.enable = lib.mkEnableOption "Enable rust module";
          };
          config = lib.mkIf config.my.rust.enable {
            home.packages = with pkgs; [
              cargo
              rustc
              rust-analyzer
              rustPlatform.rustLibSrc
            ];
          };
        }
      )
    ];
  };
}
