#!/usr/bin/env bash

set -e

# Common cleanup for NixOS rebuild issues
echo "Cleaning up common conflicts..."

# Remove Chromium lock
rm -f /home/warby/.config/chromium/Default/LOCK
echo "Removed Chromium lock."

# Backup GTK configs if they exist
if [ -d /home/warby/.config/gtk-3.0 ]; then
  rm -rf /home/warby/.config/gtk-3.0
  echo "Removed GTK 3.0 config."
fi
if [ -d /home/warby/.config/gtk-4.0 ]; then
  rm -rf /home/warby/.config/gtk-4.0
  echo "Removed GTK 4.0 config."
fi
if [ -f /home/warby/.gtkrc-2.0 ]; then
  rm -f /home/warby/.gtkrc-2.0
  echo "Removed GTK 2.0 config."
fi

# Remove Brave backup conflict
rm -f /home/warby/.config/BraveSoftware/Brave-Browser/Default/Preferences.backup
echo "Removed Brave Preferences backup."

# Copy Firefox prefs if missing (automates initial setup)
if [ ! -f ./firefox-prefs.js ]; then
  cp /home/warby/.mozilla/firefox/hgyrac4q.default/prefs.js ./firefox-prefs.js
  echo "Copied Firefox prefs to ./firefox-prefs.js for declarative management."
fi

# Run rebuild
cd /home/warby/Workspace/Nixos
sudo chmod -R a+rX /home/warby/Workspace/Nixos
sudo nixos-rebuild switch --flake .#dell-potato --impure

echo "Rebuild complete."
