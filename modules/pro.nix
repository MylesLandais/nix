{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gimp
    krita
    blender
    obs-studio
    audacity
    opencv
  ];
}