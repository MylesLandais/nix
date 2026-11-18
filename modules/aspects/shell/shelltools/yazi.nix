{ lib, ... }:
{
  flake.modules.homeManager.shelltools = lib.mkOrder 1130 {
    imports = [
      (
        {
          config,
          lib,
          ...
        }:
        {
          options = {
            my.yazi.enable = lib.mkEnableOption "Enable yazi module";
          };

          config = lib.mkIf config.my.yazi.enable {
            programs.yazi = {
              enable = true;
              enableZshIntegration = true;
              shellWrapperName = "yy";
              settings = {
                linemode = "size";
                show_hidden = true;
                show_symlink = true;
                sort_by = "natural";
                sort_dir_first = true;
                sort_reverse = false;
                sort_sensitive = false;
              };
            };
          };
        }
      )
    ];
  };
}
