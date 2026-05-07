{ config, pkgs, ... }:
{
  virtualisation.oci-containers.containers.jupyter = {
    autoStart = true;
    image = "jupyter/base-notebook";
    ports = [ "8888:8888" ];
  };
}
