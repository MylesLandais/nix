{
  lib,
  config,
  ...
}:
{
  options = {
    my.eza.enable = lib.mkEnableOption "Enable eza module";
  };

  config = lib.mkIf config.my.eza.enable {
    programs.eza.enable = true;
  };
}
