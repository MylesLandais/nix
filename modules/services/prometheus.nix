{ ... }:
{
  flake.nixosModules.prometheus =
    { config, ... }:
    {
      services.prometheus.exporters.node = {
        enable = true;
        openFirewall = true;
        enabledCollectors = [
          "systemd"
          "logind"
        ];
      };

      services.promtail = {
        enable = true;
        configuration = {
          server = {
            http_listen_port = 3101;
            grpc_listen_port = 0;
          };
          positions.filename = "/tmp/positions.yaml";
          clients = [
            {
              url = "https://loki.pik8s.universe.home/loki/api/v1/push";
              tls_config.insecure_skip_verify = true;
            }
          ];
          scrape_configs = [
            {
              job_name = "journal";
              journal = {
                max_age = "12h";
                labels = {
                  job = "systemd-journal";
                  host = config.host.hostName;
                };
              };
              relabel_configs = [
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "unit";
                }
              ];
            }
          ];
        };
      };
    };
}
