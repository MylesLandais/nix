_: {
  flake.modules.homeManager.prompt =
    {
      lib,
      config,
      ...
    }:
    {

      options = {
        my.prompt.enable = lib.mkEnableOption "Enable prompt module";
      };
      config = lib.mkIf config.my.prompt.enable {
        my.starship.enable = lib.mkDefault true;
      };
    };
}
