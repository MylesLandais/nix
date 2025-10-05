{ config, pkgs, ... }:

{
  # Jupyter container for Python development
  virtualisation.oci-containers.containers = {
    "jupyter" = {
      image = "jupyter/scipy-notebook:latest";
      ports = [ "8888:8888" ];
      volumes = [
        "/home/warby/Workspace/Jupyter:/home/jovyan/work"
      ];
      environment = {
        TZ = "America/New_York";
        JUPYTER_TOKEN = "devsandbox123";
      };
      autoStart = true;
    };
  };

  # Open firewall port for Jupyter
  networking.firewall.allowedTCPPorts = [ 8888 ];
}