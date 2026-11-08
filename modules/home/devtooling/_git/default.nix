{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    my.git.enable = lib.mkEnableOption "Enable git module";
  };

  config = lib.mkIf config.my.git.enable {
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
          # TODO(ssh): this line never reaches ~/.config/git/config. The
          # signing.* options above emit their own `gpg.ssh.program`, and that
          # section replaces this one, so local verification fails ("needs
          # gpg.ssh.allowedSignersFile") and every commit shows %G? = N even
          # though it's signed. Nest it as `gpg.ssh.allowedSignersFile` so the
          # two merge. Separately, ~/.ssh/bw.pub isn't a GitHub *signing* key,
          # so pushed commits show "Unverified": run `gh auth refresh -h github.com
          # -s admin:ssh_signing_key` and `gh ssh-key add ~/.ssh/bw.pub --type signing`.
          "gpg.ssh".allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
          # Route HTTPS credential prompts to the GNOME keyring via libsecret,
          # so first-time auth uses the seahorse GTK askpass and subsequent
          # ops fetch silently from the keyring instead of falling through to
          # NixOS's x11_ssh_askpass default.
          credential.helper = "${pkgs.git.override { withLibsecret = true; }}/bin/git-credential-libsecret";
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
