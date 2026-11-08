{
  lib,
  config,
  ...
}:
{
  options = {
    my.zoxide.enable = lib.mkEnableOption "Enable zoxide module";
  };

  config = lib.mkIf config.my.zoxide.enable {
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
