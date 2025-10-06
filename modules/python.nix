{ config, pkgs, ... }:

# let
#   # Define required Python packages for Jupyter
#   pythonPackages = with pkgs.python3Packages; [
#     jupyter
#     jupyterlab
#     ipykernel
#     numpy
#     pandas
#     matplotlib
#     # Add more as needed
#   ];

#   # Build a custom lightweight Jupyter image
#   jupyterImage = pkgs.dockerTools.buildImage {
#     name = "custom-jupyter";
#     tag = "latest";
#     copyToRoot = [
#       (pkgs.buildEnv {
#         name = "jupyter-env";
#         paths = pythonPackages ++ [ pkgs.python3 ];
#         pathsToLink = [ "/bin" "/lib" ];
#       })
#     ];
#     config = {
#       Cmd = [ "${pkgs.python3}/bin/jupyter" "notebook" "--ip=0.0.0.0" "--port=8888" "--no-browser" "--allow-root" ];
#       WorkingDir = "/home/jovyan/work";
#       Env = [
#         "JUPYTER_TOKEN=devsandbox123"
#         "TZ=America/New_York"
#       ];
#     };
#   };
# in
{
  # Jupyter container for Python development - commented out due to build issues
  # virtualisation.oci-containers.containers = {
  #   "jupyter" = {
  #     imageFile = jupyterImage;
  #     ports = [ "8888:8888" ];
  #     volumes = [
  #       "/home/warby/Workspace/Jupyter:/home/jovyan/work"
  #     ];
  #     environment = {
  #       TZ = "America/New_York";
  #       JUPYTER_TOKEN = "devsandbox123";
  #     };
  #     autoStart = true;
  #   };
  # };

  # Open firewall port for Jupyter - commented out
  # networking.firewall.allowedTCPPorts = [ 8888 ];
}