{
  flake.modules.homeManager.prompt =
    {
      lib,
      config,
      ...
    }:
    {
      options = {
        my.starship.enable = lib.mkEnableOption "Enable starship module";
      };
      config = lib.mkIf config.my.starship.enable {
        programs.starship =
          let
            kanagawa = import ./starship/_kanagawa.nix;
          in
          {
            enable = true;
            enableZshIntegration = true;
            settings = kanagawa;
          };
      };
    };
}
