{ config, pkgs, ... }:

# ============================================================================
# Python Development Environment Module
# ============================================================================
#
# This module provides a Python data science environment through a Jupyter
# notebook container. It includes essential scientific computing packages
# for machine learning, data analysis, and interactive development.
#
# CONTAINER CONFIGURATION:
# ========================
# - Image: jupyter/minimal-notebook:latest (1.56GB)
# - Port: 8888 (accessible via http://localhost:8888)
# - Token: devsandbox123 (for authentication)
# - Workspace: /home/warby/Workspace/Jupyter mounted to /home/jovyan/work
#
# INCLUDED PACKAGES:
# ==================
# - Jupyter Lab: Modern web-based interface for notebooks
# - Python 3.11+: Latest stable Python version
# - NumPy: Fundamental package for array computing
# - Pandas: Data manipulation and analysis library
# - Matplotlib: Comprehensive plotting library
# - SciPy: Scientific computing library
# - Scikit-learn: Machine learning in Python
#
# USAGE:
# ======
# 1. Import this module in your NixOS configuration
# 2. Access Jupyter at http://localhost:8888 with token 'devsandbox123'
# 3. Work in mounted directory: /home/warby/Workspace/Jupyter
#
# OPTIMIZATION NOTES:
# ===================
# The experimental ultra-minimal custom image is commented out due to
# Nix build complexity. Current implementation uses official Jupyter
# minimal-notebook image which provides good balance of size and features.
#
# Future: Custom distroless-style image targeting ~500MB (67% reduction)
# ============================================================================

# EXPERIMENTAL: Custom ultra-minimal Jupyter image (currently disabled)
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