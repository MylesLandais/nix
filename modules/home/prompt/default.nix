_: {
  flake.modules.homeManager.prompt =
    {
      lib,
      config,
      ...
    }:
    {
      imports = [
        ./_starship
      ];

      options = {
        my.prompt.enable = lib.mkEnableOption "Enable prompt module";
      };
      config = lib.mkIf config.my.prompt.enable {
        my.starship.enable = lib.mkDefault true;
      };
    };
}
