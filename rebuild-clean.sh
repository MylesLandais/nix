#!/usr/bin/env bash

set -e

echo "Running rebuild-clean.sh..."

# Cleanup steps (no sudo needed - user files)
echo "Cleaning up common conflicts..."
rm -f ~/.config/chromium/SingletonLock
rm -f ~/.config/BraveSoftware/Brave-Browser/Default/Preferences.backup

# Fix repo permissions (non-sudo - user owns the files)
echo "Fixing repo permissions..."
# chmod -R u+rwX ~/Workspace/Nixos 2>/dev/null || true  # No sudo needed, user owns files

# Warn about dirty Git tree
if ! git diff --quiet HEAD 2>/dev/null; then
    echo "warning: Git tree is dirty"
fi

# Rebuild (uses passwordless sudo for nixos-rebuild only)
echo "Building the system configuration..."
sudo nixos-rebuild switch --flake .#dell-potato --impure

echo "Rebuild complete!"
