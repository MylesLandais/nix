# ============================================================================
# Home Manager Configuration for Dell OptiPlex
# ============================================================================
#
# This configuration manages user-specific settings and packages for the
# dell-potato host using Home Manager. It provides a declarative way to
# configure user environments, packages, and dotfiles.
#
# USER CONFIGURATION:
# ===================
# - Username: warby
# - Home directory: /home/warby
# - State version: 24.11 (matches NixOS stateVersion)
#
# PACKAGES INCLUDED:
# =================
# - Development tools: vscode, git, various language toolchains
# - Media applications: gimp, vlc
# - System tools: neofetch, htop
# - Communication: discord (via vesktop)
# - Productivity: libreoffice
#
# GIT CONFIGURATION:
# =================
# - User name and email should be configured
# - Default editor and other preferences
#
# SHELL CONFIGURATION:
# ===================
# - Bash with custom aliases
# - Fish shell support
# - Zsh support via modules
#
# USAGE:
# ======
# This file is imported by the flake.nix configuration and applied
# automatically when rebuilding the system.
#
# ============================================================================

{ config, pkgs, ... }:

{
  # Home Manager basic configuration
  home.username = "warby";
  home.homeDirectory = "/home/warby";
  home.stateVersion = "24.11";

  # User packages - comprehensive development and productivity suite
  home.packages = with pkgs; [
    # Development tools
    vscode
    git
    vim
    neovim
    helix
    zed-editor

    # Programming languages and toolchains
    python3
    nodejs
    rustc
    cargo
    go
    elixir
    gleam
    lua
    luajit

    # Development utilities
    docker-compose
    kubectl
    kubernetes-helm
    terraform
    ansible

    # Media and graphics
    gimp
    inkscape
    vlc
    mpv
    ffmpeg
    imagemagick

    # System tools and monitoring
    neofetch
    htop
    btop
    nvtopPackages.full
    tree
    jq
    yq
    ripgrep
    fd
    fzf
    bat
    eza
    zoxide
    atuin

    # Communication and productivity
    vesktop          # Discord client
    thunderbird      # Email client
    libreoffice      # Office suite
    obsidian         # Note taking
    zathura          # PDF viewer
    alacritty        # Terminal emulator
    ghostty          # Modern terminal

    # Gaming and entertainment
    steam
    lutris
    heroic
    protontricks
    mangohud
    gamescope

    # Web browsers and tools
    firefox
    ungoogled-chromium
    brave
    wget
    curl
    httpie

    # Security and encryption
    gnupg
    pinentry-gnome3
    openssl
    age
    sops

    # System utilities
    gparted
    baobab          # Disk usage analyzer
    gnome-disk-utility

    # Fun and miscellaneous
    cowsay
    fortune
    figlet
    lolcat
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "Warby";
    userEmail = "warby@example.com";  # TODO: Update with actual email
    extraConfig = {
      init.defaultBranch = "main";
      core.editor = "vim";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  # Bash shell configuration
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      # Custom aliases for improved productivity
      alias ll='ls -la'
      alias la='ls -A'
      alias l='ls -CF'
      alias grep='grep --color=auto'
      alias fgrep='fgrep --color=auto'
      alias egrep='egrep --color=auto'

      # Development aliases
      alias gs='git status'
      alias ga='git add'
      alias gc='git commit'
      alias gp='git push'
      alias gl='git log --oneline'

      # System monitoring
      alias top='htop'
      alias df='df -h'
      alias du='du -h'

      # NixOS specific
      alias nix-rebuild='sudo nixos-rebuild switch --flake /etc/nixos'
      alias nix-update='sudo nix flake update /etc/nixos'
      alias nix-clean='sudo nix-collect-garbage -d'

      # AMD graphics monitoring (when GPU is present)
      alias amd-top='amdgpu_top'
      alias gpu-info='glxinfo | grep -E "(renderer|vendor|version)"'
    '';

    # Bash history configuration
    historyControl = [ "ignoredups" "ignorespace" ];
    historySize = 10000;
    historyFileSize = 20000;
  };

  # Fish shell support
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Fish shell customizations
      set -g fish_greeting ""

      # Custom functions and aliases
      function ll
        ls -la $argv
      end

      function gs
        git status $argv
      end

      function nix-switch
        sudo nixos-rebuild switch --flake /etc/nixos $argv
      end
    '';
  };

  # Starship prompt configuration
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = "$username$hostname$directory$git_branch$git_status$character";
      username = {
        style_user = "bright-blue";
        style_root = "bright-red";
      };
      hostname = {
        style = "bright-green";
      };
      directory = {
        style = "bright-cyan";
      };
      git_branch = {
        style = "bright-purple";
      };
      character = {
        success_symbol = "[➜](bright-green)";
        error_symbol = "[✗](bright-red)";
      };
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Additional configuration files and dotfiles can be managed here
  # Example:
  # home.file.".config/some-app/config".source = ./dotfiles/some-app-config;

  # XDG configuration
  xdg.enable = true;
  xdg.userDirs.enable = true;
  xdg.userDirs.createDirectories = true;
}