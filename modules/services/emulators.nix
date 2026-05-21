_: {
  flake.nixosModules.emulators =
    { config, lib, pkgs, ... }:
    {
      options.host.emulators.enable = lib.mkEnableOption "console / handheld emulators";

      config = lib.mkIf config.host.emulators.enable {
        nixpkgs.config.allowUnfree = true;

        environment.systemPackages = with pkgs; [
          (retroarch.withCores (cores: with cores; [
            mgba
            snes9x
            mupen64plus
            genesis-plus-gx
            beetle-psx-hw
          ]))
          dolphin-emu
          pcsx2
          mgba
          ppsspp
          mame
        ];
      };
    };
}
