_: {
  # Pre-staged NetworkManager profiles. Dropped into
  # /etc/NetworkManager/system-connections/ as 0600 root-owned files so they
  # auto-connect on first boot. Enable via host config:
  #   imports = [ inputs.self.nixosModules.wifiProfiles ];
  #
  # TODO: PSKs in plaintext — migrate to agenix during secrets rework
  # (broader merge plan). Acceptable interim for home-office SSIDs.
  flake.nixosModules.wifiProfiles =
    { lib, ... }:
    {
      networking.networkmanager.enable = lib.mkDefault true;

      environment.etc."NetworkManager/system-connections/netgear-5g.nmconnection" = {
        mode = "0600";
        user = "root";
        group = "root";
        text = ''
          [connection]
          id=netgear-5g
          uuid=8a1f4b6e-5c2a-4e3d-9f7b-6a4c8d2e1f0a
          type=wifi
          autoconnect=true

          [wifi]
          mode=infrastructure
          ssid=netgear-5g

          [wifi-security]
          auth-alg=open
          key-mgmt=wpa-psk
          psk=crispyvalley893

          [ipv4]
          method=auto

          [ipv6]
          method=auto
          addr-gen-mode=default
        '';
      };
    };
}
