{ pkgs, ... }:

let
  pythonPackages = with pkgs.python3Packages; [
    jupyter
    jupyterlab
    ipykernel
    numpy
    pandas
    matplotlib
    scipy
    scikit-learn
  ];

  jupyterImage = pkgs.dockerTools.buildLayeredImage {
    name = "custom-jupyter";
    tag = "latest";
    contents = [ pkgs.cacert ];
    config = {
      Cmd = [
        "${pkgs.python3}/bin/jupyter"
        "notebook"
        "--ip=0.0.0.0"
        "--port=8888"
        "--no-browser"
        "--allow-root"
      ];
      WorkingDir = "/home/jovyan/work";
      Env = [
        "JUPYTER_TOKEN=devsandbox123"
        "TZ=America/New_York"
      ];
    };
  };
in
jupyterImage