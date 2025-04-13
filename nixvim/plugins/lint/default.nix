{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    lint.enable = lib.mkEnableOption "Enable lint nixvim plugin module";
  };

  config = lib.mkIf config.lint.enable {
    programs.nixvim.plugins = {
      lint = {
        enable = true;
        lintersByFt = {
          text = ["value"];
          dockerfile = ["hadolint"];
          terraform = ["tflint"];
          go = ["revive"];
        };
      };
    };
  };
}
