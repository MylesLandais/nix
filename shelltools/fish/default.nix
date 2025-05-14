{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    fish.enable = lib.mkEnableOption "Enable fish module";
  };

  config = lib.mkIf config.fish.enable {
    programs.fish = {
      enable = true;
      shellInit = ''
        set -U fish_term24bit 1
        set SSH_AUTH_SOCK /home/franky/.bitwarden-ssh-agent.sock
        fish_vi_key_bindings
      '';

      shellAliases = {
        ll = "eza --icons --git --git-ignore --git -F -l";
        cat = "bat";
        ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
        hms = "home-manager switch";
        k = "kubectl";
        fzfcheckout = "git branch | fzf | xargs git checkout";
        rebuild = "sudo nixos-rebuild switch --flake ~/.config/home-manager";
        upgrade = "nix flake update --flake ~/.config/home-manager && sudo nixos-rebuild switch --flake ~/.config/home-manager --upgrade";
        cleanup = "sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 2d  && sudo nix-collect-garbage --delete-older-than 2d";
      };
    };
  };
}
