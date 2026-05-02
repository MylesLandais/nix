_: {
  flake.nixosModules.ollama =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      services.ollama = {
        enable = true;
        port = 11434;
        host = "0.0.0.0";
        openFirewall = true;
        package =
          if config.host.gpuType == "amd" then
            pkgs.ollama-rocm
          else if config.host.gpuType == "nvidia" then
            pkgs.ollama-cuda
          else
            pkgs.ollama;
      };

      services.open-webui = {
        enable = false;
        openFirewall = true;
        environment = {
          OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
          WEBUI_AUTH = "False";
        };
        host = "192.168.0.38";
        port = 8088;
      };

      systemd.services.lms = {
        description = "lms systemd unit";
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          RestartSec = 5;
          ExecStart = "${pkgs.lmstudio}/bin/lms server start";
          NoNewPrivileges = true;
          User = "franky";
          Group = "users";
          WorkingDirectory = "/var/lib/lms";
          Restart = "always";
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = false;
        };
        enable = false;
      };
    };
}
