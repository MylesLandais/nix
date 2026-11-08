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
        gtk-mod.enable = lib.mkEnableOption "Enable gtk module";
      };
      config = lib.mkIf config.gtk-mod.enable {
        gtk-conf.enable = lib.mkDefault true;
      };
    };
}
