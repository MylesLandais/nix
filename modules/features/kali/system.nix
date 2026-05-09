{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./theme.nix
    ./greeter.nix
  ];

  config = lib.mkIf config.host.kali.enable {
    assertions = [
      {
        assertion = config.host.desktop == "xfce";
        message = "host.kali.enable requires host.desktop = \"xfce\"; Kali ships an XFCE session.";
      }
    ];

    environment.systemPackages = import ./packages.nix {
      inherit pkgs;
      inherit (config.host.kali) profile;
    };
  };
}
