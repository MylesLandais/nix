{
  config,
  lib,
  ...
}: {
  options = {
    yazi.enable = lib.mkEnableOption "Enable yazi module";
  };

  config = lib.mkIf config.yazi.enable {
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
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
