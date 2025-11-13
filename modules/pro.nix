{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gimp # Image editing
    krita # Digital painting
    blender # 3D modeling and animation
    obs-studio # Screen recording and streaming
    audacity # Audio editing
    mixxx
  ];
}
