{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    git_helpers.enable = lib.mkEnableOption "Enable git nixvim plugins module";
  };

  config = lib.mkIf config.git_helpers.enable {
    programs.nixvim.plugins = {
      gitblame = {
        enable = false;
      };
      git-worktree = {
        enable = true;
        enableTelescope = true;
      };
      gitsigns = {
        enable = true;
        settings = {
          current_line_blame = true;
          current_line_blame_opts = {
            virt_text = true;
            virt_text_pos = "eol";
          };
          signcolumn = true;
          signs = {
            add = {
              text = "│";
            };
            change = {
              text = "│";
            };
            changedelete = {
              text = "~";
            };
            delete = {
              text = "_";
            };
            topdelete = {
              text = "‾";
            };
            untracked = {
              text = "┆";
            };
          };
          watch_gitdir = {
            follow_files = true;
          };
        };
      };
      lazygit = {
        enable = true;
      };
      git-conflict = {
        enable = true;
        settings = {
          default_commands = true;
          default_mappings = {
            both = "b";
            next = "nn";
            none = "0";
            ours = "o";
            prev = "p";
            theirs = "t";
          };
          disable_diagnostics = false;
          highlights = {
            current = "DiffText";
            incoming = "DiffAdd";
          };
          list_opener = "copen";
        };
      };
    };
  };
}
