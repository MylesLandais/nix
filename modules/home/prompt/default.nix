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
        prompt.enable = lib.mkEnableOption "Enable prompt module";
      };
      config = lib.mkIf config.prompt.enable {
        starship.enable = lib.mkDefault true;
      };
    };
}
