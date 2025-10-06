# ============================================================================
# Professional Creative Tools Module
# ============================================================================
#
# This module provides a collection of professional-grade open source software
# for creative workflows, including image editing, 3D modeling, video recording,
# audio editing, and computer vision development.
#
# TOOLS INCLUDED:
# ===============
# - GIMP: Advanced image editor (Photoshop alternative)
# - Krita: Digital painting and illustration software
# - Blender: 3D creation suite (modeling, animation, rendering)
# - OBS Studio: Screen recording and live streaming software
# - Audacity: Multi-track audio editor and recorder
# - OpenCV: Computer vision and machine learning library
#
# USAGE:
# ======
# Import this module in home.nix to enable creative tools for the user.
# These tools are suitable for content creation, multimedia production,
# and AI/ML computer vision projects.
#
# DEPENDENCIES:
# =============
# - GTK/Qt libraries (automatically handled by Nix)
# - Hardware acceleration for graphics-intensive tasks
#
# ============================================================================

{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gimp        # Image editing
    krita       # Digital painting
    blender     # 3D modeling and animation
    obs-studio  # Screen recording and streaming
    audacity    # Audio editing
    opencv      # Computer vision library
  ];
}