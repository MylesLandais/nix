{ ... }:
{
  flake.nixosModules.krakenOtel =
    { pkgs, ... }:
    {
      services.opentelemetry-collector = {
        enable = true;
        package = pkgs.opentelemetry-collector-contrib;
        settings = {
          receivers.hostmetrics = {
            collection_interval = "60s";
            scrapers = {
              cpu = { };
              disk = { };
              load = { };
              filesystem = { };
              memory = { };
              network = { };
            };
          };
          processors.resourcedetection = {
            detectors = [
              "env"
              "system"
            ];
            system.hostname_sources = "os";
          };
          extensions = {
            zpages = { };
            health_check = { };
          };
          exporters.otlphttp = {
            endpoint = "https://otelcollector.universe.home:443";
            tls = {
              insecure = false;
              insecure_skip_verify = true;
            };
          };
          service = {
            telemetry.metrics.address = "0.0.0.0:8888";
            extensions = [
              "zpages"
              "health_check"
            ];
            pipelines."metrics/hostmetrics" = {
              receivers = [ "hostmetrics" ];
              processors = [ "resourcedetection" ];
              exporters = [ "otlphttp" ];
            };
          };
        };
      };
    };
}
