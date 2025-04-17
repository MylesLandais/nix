{
  pkgs,
  lib,
  config,
  rust,
  ...
}: {
  options = {
    rust.enable = lib.mkEnableOption "Enable rust module";
  };
  config = lib.mkIf config.rust.enable {
    home.packages = with pkgs; [
      cargo
      rust-analyzer
    ];
  };
}
