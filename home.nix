{
  pkgs,
  lib,
  vars,
  config,
  inputs,
  ...
}:
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "franky";
  home.enableNixpkgsReleaseCheck = false;
  home.homeDirectory = "/home/franky";

  home.stateVersion = "24.11"; # Please read the comment before changing.
  imports = [
    ./hypr.nix
    ./prompt
    ./nixvim
    ./shelltools
    ./devtooling
    ./gtk
    ./hyprpanel.nix
    inputs.stylix.homeModules.stylix
    inputs.tokyonight.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    # jetbrains.goland
    ags
    alejandra
    bind
    bitwarden-desktop
    brave
    btop
    cava
    coreutils
    cosmic-files
    devbox
    dysk
    element-desktop
    exercism
    fastfetch
    fd
    ffmpeg
    fishPlugins.forgit
    gamemode
    gcc
    git-lfs
    glava
    gnome-themes-extra
    gowall
    gpgme
    gtk-engine-murrine
    hack-font
    heroic
    hubble
    hyprpanel
    hyprpaper
    hyprshot
    jetbrains-mono
    jq
    kanagawa-gtk-theme
    kanagawa-icon-theme
    lazydocker
    lazygit
    libnotify
    libnvidia-container
    markdown-oxide
    matugen
    mpv
    nix-search-tv
    nixos-generators
    nvidia-docker
    nwg-look
    ollama
    opencloud-desktop
    pavucontrol
    playerctl
    plex-mpv-shim
    pulseaudio
    pulseaudio-ctl
    pulsemixer
    revive
    ripgrep
    sassc
    solaar
    statping-ng
    telegram-desktop
    terraform-ls
    tflint
    tldr
    tmux
    tokyonight-gtk-theme
    treefmt
    ttyd
    vesktop
    vhs
    vial
    virtualgl
    vulkan-tools
    waybar
    wl-clipboard
    wlogout
  ];

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 22;
  };
  prompt.enable = true;
  devtooling.enable = true;
  shelltools.enable = true;
  programs.git.delta.tokyonight.enable = false;
  programs.git.lfs.enable = true;
  programs.onlyoffice.enable = true;
  programs.wofi.enable = true;
  stylix = {
    autoEnable = false;
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa-dragon.yaml";
    targets = {
      bat.enable = true;
      btop.enable = true;
      gtk.enable = true;
      hyprland.enable = true;
      k9s.enable = true;
      kubecolor.enable = true;
      lazygit.enable = true;
      mpv.enable = true;
      qt.enable = true;
      vesktop.enable = true;
      wofi.enable = true;
    };
  };
  nixvimcfg.enable = true;
  gtk-mod.enable = true;

  home.file = {
    "${config.xdg.configHome}/ghostty/config".text = ''
      theme = "Kanagawa Dragon"
      background-opacity = 0.9
      window-decoration = false
      font-family = "Hack Nerd Font"
    '';
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
