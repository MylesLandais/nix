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
        my.shelltools.enable = lib.mkEnableOption "Enable shell tools module";
      };
      config = lib.mkIf config.my.shelltools.enable {
        my.atuin.enable = lib.mkDefault true;
        my.bat.enable = lib.mkDefault true;
        my.direnv.enable = lib.mkDefault true;
        my.eza.enable = lib.mkDefault true;
        my.fzf.enable = lib.mkDefault true;
        my.zoxide.enable = lib.mkDefault true;
        my.zsh.enable = lib.mkDefault true;
        my.fish.enable = lib.mkDefault true;
        my.yazi.enable = lib.mkDefault true;
      };
    };
}
