{ config, lib, ... }:

with lib;

let
  cfg = config.programs.chromium;
in
{
  config = mkIf cfg.enable {
    programs.chromium = {
      extensions = [
        { id = "mmioliijnhnoblpgimnlajmefafdfilb"; } # Shazam
      ];
    };
  };
}
