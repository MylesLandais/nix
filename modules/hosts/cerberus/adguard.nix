{
  flake.modules.nixos.cerberus =
    # Cerberus LAN DNS filter.
    _: {
      services.adguardhome = {
        enable = true;
        openFirewall = true;
        port = 8080;
        settings = {
          dns = {
            bind_host = "0.0.0.0";
            port = 53;
            upstream_dns = [
              "https://dns.quad9.net/dns-query"
              "tls://dns.quad9.net"
            ];
            bootstrap_dns = [
              "9.9.9.9"
              "149.112.112.112"
            ];
            ratelimit = 30;
            cache_size = 8388608;
          };
          filtering = {
            enabled = true;
          };
        };
      };
    };
}
