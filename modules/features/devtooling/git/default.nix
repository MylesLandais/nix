{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    git.enable = lib.mkEnableOption "Enable git module";
  };

  config = lib.mkIf config.git.enable {
    programs = {

      git = {
        enable = true;
        package = pkgs.git;
        signing.format = "ssh";
        signing.key = "~/.ssh/bw.pub";
        signing.signByDefault = true;
        settings = {
          user = {
            name = "Myles Landais";
            email = "landais.myles@gmail.com";
            signingkey = "~/.ssh/bw.pub";
          };
          commit.gpgsign = true;
          gpg.format = "ssh";
          "gpg.ssh".allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          alias = {
            lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
          };
        };
      };
      delta = {
        enable = true;
        options = {
          decorations = {
            commit-decoration-style = "bold yellow box ul";
            file-style = "bold yellow ul";
            file-decoration-style = "none";
            hunk-header-decoration-style = "yellow box";
          };
          interactive = {
            keep-plus-minus-markers = true;
          };
          features = "decorations";
        };
      };
      git-worktree-switcher.enable = true;
    };

    home.file.".ssh/allowed_signers".text = ''
      landais.myles@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN26TcFkEK22/wuioiuHxCKZw0C1cdkVzgGMA+m7Jeei
    '';
  };
}
