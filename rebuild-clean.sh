#!/usr/bin/env bash

set -e

# Common cleanup for NixOS rebuild issues
echo "Cleaning up common conflicts..."

# Remove Chromium lock
rm -f /home/warby/.config/chromium/Default/LOCK
echo "Removed Chromium lock."

# Backup GTK configs if they exist
if [ -d /home/warby/.config/gtk-3.0 ]; then
  mv /home/warby/.config/gtk-3.0 /home/warby/.config/gtk-3.0.bak
  echo "Backed up GTK 3.0 config."
fi
if [ -d /home/warby/.config/gtk-4.0 ]; then
  mv /home/warby/.config/gtk-4.0 /home/warby/.config/gtk-4.0.bak
  echo "Backed up GTK 4.0 config."
fi
if [ -f /home/warby/.gtkrc-2.0 ]; then
  mv /home/warby/.gtkrc-2.0 /home/warby/.gtkrc-2.0.bak
  echo "Backed up GTK 2.0 config."
fi

# Run rebuild
cd /home/warby/Workspace/Nixos
sudo nixos-rebuild switch --flake .#dell-potato

echo "Rebuild complete."
