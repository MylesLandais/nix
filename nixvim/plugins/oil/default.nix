{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    oil.enable = lib.mkEnableOption "Enable oil nixvim plugin module";
  };

  config = lib.mkIf config.packer.enable {
    programs.nixvim.plugins.oil = {
      enable = true;
      settings = {
        win_options = {
          signcolumn = "yes:2";
        };
      };
    };
    programs.nixvim.plugins.oil-git-status = {
      enable = true;
      lazyLoad = {
        settings = {
          enable = true;
          enabled = true;
          before.__raw = ''
            function()
              require("oil").setup({win_options = { singcolumn = "yes:2" }})
              end
          '';
          #keys = [
          # {
          #   __unkeyed-1 = "-";
          #   __unkeyed-3 = "<CMD>Oil<CR>";
          #   desk = "Toggle oil";
          # }
          #];
        };
      };
      settings = {
        show_ignored = true;
        index = {
          "[\"!\"]" = "!";
          "[\"?\"]" = "?";
          "[\"A\"]" = "A";
          "[\"C\"]" = "C";
          "[\"D\"]" = "D";
          "[\"M\"]" = "M";
          "[\"R\"]" = "R";
          "[\"T\"]" = "T";
          "[\"U\"]" = "U";
          "[\" \"]" = " ";
        };
        working_tree = {
          "[\"!\"]" = "!";
          "[\"?\"]" = "?";
          "[\"A\"]" = "A";
          "[\"C\"]" = "C";
          "[\"D\"]" = "D";
          "[\"M\"]" = "M";
          "[\"R\"]" = "R";
          "[\"T\"]" = "T";
          "[\"U\"]" = "U";
          "[\" \"]" = " ";
        };
      };
    };
  };
}
