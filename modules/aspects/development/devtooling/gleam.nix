{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1060 {
    imports = [
      (
        {
          pkgs,
          lib,
          config,
          ...
        }:
        {
          options = {
            my.gleam.enable = lib.mkEnableOption "Enable gleam module";
          };
          config = lib.mkIf config.my.gleam.enable {
            home.packages = with pkgs; [
              gleam
              rebar3
              erlang_27 # there seems to be an issue with erlang27(latest version) where gleam tends to fail on running any project https://forum.exercism.org/t/escript-error-in-gleam-exercise/11486
            ];
          };
        }
      )
    ];
  };
}
