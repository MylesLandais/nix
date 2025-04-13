{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "franky";
  home.enableNixpkgsReleaseCheck = false;
  home.homeDirectory = "/home/franky";
  nixpkgs.config = {
    allowUnfree = true;
  };

  home.stateVersion = "24.11"; # Please read the comment before changing.
  imports = [
    ./hypr.nix
    ./prompt
    ./nixvim
    ./shelltools
    ./devtooling
    ./keymaps.nix
    ./vimopts.nix
    ./gtk
    #./hyprpanel.nix
    inputs.nixvim.homeManagerModules.nixvim
    inputs.tokyonight.homeManagerModules.default
  ];
  # environment.
  home.packages = with pkgs; [
    hyprpanel
    pulseaudio-ctl
    pulseaudio
    sassc
    gnome-themes-extra
    gtk-engine-murrine
    cavalier
    alejandra
    markdown-oxide
    vhs
    virtualgl
    vulkan-tools
    nix-search-tv
    ffmpeg
    ttyd
    vesktop
    bitwarden-desktop
    lazygit
    lazydocker
    ripgrep
    gcc
    jq
    wofi
    wlogout
    hack-font
    playerctl
    tmux
    hyprshot
    pavucontrol
    wl-clipboard
    waybar
    jetbrains-mono
    fastfetch
    nwg-look
    ollama
    hyprpaper
    devbox
    bind
    ags
    libnotify
    exercism
    coreutils
    fd
    tokyonight-gtk-theme
    kanagawa-gtk-theme
    kanagawa-icon-theme
    tldr
    btop
    nvtopPackages.nvidia
    gamemode
    hubble
    brave
    telegram-desktop
    statping-ng
    revive
    terraform-ls
    tflint
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
  programs.bat.tokyonight.enable = true;
  programs.git.delta.tokyonight.enable = false;
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    luaLoader.enable = false;
    extraConfigLua = "require('go').setup()";
    extraPlugins = with pkgs.vimPlugins; [
      plenary-nvim
      go-nvim
      nvim-treesitter.withAllGrammars
    ];
    plugins = {
      web-devicons = {
        enable = true;
      };
    };
    colorschemes = {
      kanagawa = {
        enable = true;
        settings = {
          transparent = false;
          theme = "wave";
        };
      };
    };
  };
  nixvimcfg.enable = true;
  gtk-mod.enable = true;

  home.file = {
    "${config.xdg.configHome}/ghostty/config".text = ''
      theme = "Kanagawa Wave"
      background-opacity = 0.9
      window-decoration = false
    '';
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
