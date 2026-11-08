_: {
  flake.modules.homeManager.gtk =
    {
      lib,
      config,
      ...
    }:
    {
      imports = [
        ./_conf
      ];

      options = {
        my.gtk-mod.enable = lib.mkEnableOption "Enable gtk module";
      };
      config = lib.mkIf config.my.gtk-mod.enable {
        my.gtk-conf.enable = lib.mkDefault true;
      };
    };
}
