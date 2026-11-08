_: {
  flake.modules.homeManager.shelltools =
    {
      lib,
      config,
      ...
    }:
    {
      imports = [
        ./_atuin
        ./_bat
        ./_direnv
        ./_eza
        ./_fish
        ./_fzf
        ./_zoxide
        ./_zsh
        ./_yazi
      ];

      options = {
        shelltools.enable = lib.mkEnableOption "Enable shell tools module";
      };
      config = lib.mkIf config.shelltools.enable {
        atuin.enable = lib.mkDefault true;
        bat.enable = lib.mkDefault true;
        direnv.enable = lib.mkDefault true;
        eza.enable = lib.mkDefault true;
        fzf.enable = lib.mkDefault true;
        zoxide.enable = lib.mkDefault true;
        zsh.enable = lib.mkDefault true;
        fish.enable = lib.mkDefault true;
        yazi.enable = lib.mkDefault true;
      };
    };
}
