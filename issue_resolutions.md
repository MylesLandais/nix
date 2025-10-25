# System Issues and Resolutions

This document tracks the issues identified and the steps taken to resolve them.

## Issue 1: Nemo File Manager Icons Appear Ugly

*   **Status:** Resolved
*   **Analysis:** Icons in the Nemo file manager are not rendering correctly, likely due to missing or incompatible icon themes in the NixOS environment.
*   **Resolution Steps:**
    1.  Added `papirus-icon-theme`, `breeze-icons`, and `gnome.adwaita-icon-theme` to `environment.systemPackages` in `/home/warby/Workspace/nix/hosts/cerberus/configuration.nix`.

## Issue 2: SMB File Shares Not Working

*   **Status:** Resolved
*   **Analysis:** SMB shares failing to mount is a frequent NixOS issue, often due to unconfigured services, permissions, or firewall blocks.
*   **Resolution Steps:**
    1.  Enabled the Samba service in `/home/warby/Workspace/nix/hosts/cerberus/configuration.nix`.
    2.  Added `cifs-utils` to `environment.systemPackages`.

## Issue 3: Wrong Terminal Emulator (Prefer Ghostty)

*   **Status:** Resolved
*   **Analysis:** The default terminal was not set to Ghostty.
*   **Resolution Steps:**
    1.  Added `ghostty` to `home.packages` in `home.nix`.
    2.  Set `home.sessionVariables.TERMINAL = "ghostty"` in `home.nix`.

## Issue 4: Missing Packages (opencode, gemini, goose)

*   **Status:** Resolved
*   **Analysis:** The commands `opencode` and `goose` were not found.
*   **Resolution Steps:**
    1.  Added flakes for `opencode` and `goose-ai` to `flake.nix`.
    2.  Added the packages to `home.packages` in `home.nix`.

## Issue 5: VSCode Warnings and Missing Config/Extensions

*   **Status:** Resolved
*   **Analysis:** VSCode showed warnings on Wayland, and some extensions were missing.
*   **Resolution Steps:**
    1.  Created `~/.config/electron-flags.conf` with Wayland-specific flags.
    2.  Added the `nix-vscode-extensions` flake to `flake.nix`.
    3.  Added the missing extensions (`kilocode.kilo-code` and `quinn.vscode-kanagawa`) to `programs.vscode.extensions` in `home.nix`.

## Issue 6: MPV Not Following Old Config

*   **Status:** Resolved
*   **Analysis:** MPV was not using the user's configuration.
*   **Resolution Steps:**
    1.  Enabled `programs.mpv` in `home.nix`.
    2.  Removed `mpv` from `home.packages` to avoid conflicts.

## Issue 7: GVFS or Mounting Issues

*   **Status:** Resolved
*   **Analysis:** GVFS was not enabled.
*   **Resolution Steps:**
    1.  Enabled `services.gvfs` in `/home/warby/Workspace/nix/hosts/cerberus/configuration.nix`.

## Issue 8: Unable to Mount Previous System OS (Dual Boot with Windows 11)

*   **Status:** Resolved
*   **Analysis:** Missing NTFS support.
*   **Resolution Steps:**
    1.  Added `ntfs3g` to `environment.systemPackages`.
    2.  Added a comment to `configuration.nix` to guide the user on adding fstab entries.

## Issue 9: Rip Old Configs from 1TB Arch Setup

*   **Status:** User Action Required
*   **Analysis:** This task requires manual intervention from the user.

## Issue 10: Displays Not Configured Correctly

*   **Status:** Resolved
*   **Analysis:** Monitor positions were not configured as desired.
*   **Resolution Steps:**
    1.  Corrected `vars.nix` to remove duplicated lines.
    2.  Adjusted the monitor positions in `hyprland.nix`.

## Issue 11: Waybar Missing Fonts (Emojis/Unicode)

*   **Status:** Resolved
*   **Analysis:** Missing fonts for icons and symbols.
*   **Resolution Steps:**
    1.  Added `font-awesome` and `nerdfonts` to `home.packages` in `home.nix`.
