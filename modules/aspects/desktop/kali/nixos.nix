# The sibling module priorities retain the original import order and configuration precedence.
_: {
  flake.modules.nixos.kali =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {

      config = lib.mkIf config.host.kali.enable {
        assertions = [
          {
            assertion = config.host.desktop == "xfce";
            message = "host.kali.enable requires host.desktop = \"xfce\"; Kali ships an XFCE session.";
          }
        ];

        environment.systemPackages = import ./_packages.nix {
          inherit pkgs;
          inherit (config.host.kali) profile;
        };
      };
    };
}
