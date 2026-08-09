{ pkgs, ... }:
{
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "warby";
      email = "landais.myles@gmail.com";
    };
  };

  programs.btop = {
    enable = true;
    settings.theme_background = false;
  };

  home.packages = with pkgs; [
    eza
    zoxide
    fzf
    bat
  ];
}
