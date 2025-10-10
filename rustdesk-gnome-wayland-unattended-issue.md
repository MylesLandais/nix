# [BLOCKER] RustDesk Unattended Access Fails on GNOME with Wayland

## Issue Description

When attempting to connect to a NixOS machine running the GNOME desktop environment (which defaults to Wayland), the RustDesk client requires interactive user permission to share the screen. A prompt appears on the host machine asking the user to select which screen to share.

This behavior prevents true unattended access, which is a critical requirement for remote IT management. The service should be able to provide a remote session without any user interaction on the host machine, especially when the machine is locked or no user is logged in.

## Environment

*   **Operating System:** NixOS
*   **Desktop Environment:** GNOME (with Wayland)
*   **Remote Access Tool:** RustDesk (`rustdesk-flutter` package)
*   **Setup:** RustDesk is configured to run as a systemd service as `root` for unattended access.

## Troubleshooting Steps Attempted

1.  **Initial Setup:**
    *   Installed the `rustdesk-flutter` package on the NixOS host.
    *   Created a `systemd` service for `rustdesk` to run on boot as the `root` user.
    *   The service was configured to start after `network-online.target`.

2.  **Forcing Graphical Session Dependency:**
    *   **Action:** Modified the `rustdesk.service` to start after `graphical-session.target`.
    *   **Reasoning:** To ensure the graphical environment was fully initialized before the service started.
    *   **Result:** The permission prompt persisted.

3.  **Virtual Display with XPra:**
    *   **Action:**
        *   Installed `xpra` and `xwayland`.
        *   Created a new `xpra.service` to run a persistent virtual X11 display (`:100`) on boot.
        *   Modified `rustdesk.service` to depend on and start after `xpra.service`.
        *   Set the `DISPLAY` environment variable for the `rustdesk` service to `:100`.
    *   **Reasoning:** To provide a non-Wayland, virtual display for RustDesk to connect to, bypassing the user's interactive Wayland session.
    *   **Result:** The permission prompt persisted, indicating that RustDesk was still defaulting to Wayland's screen capture methods.

4.  **Forcing X11 Mode via Environment Variables:**
    *   **Action:** Modified the `rustdesk.service` to explicitly unset Wayland-related environment variables (`WAYLAND_DISPLAY=` and `XDG_SESSION_TYPE=`).
    *   **Reasoning:** To force the RustDesk client to fall back to using the X11 display provided by `xpra`.
    *   **Result:** The issue remains unresolved. The interactive prompt for screen sharing still appears on the host machine.

## Current Status

The problem is a **blocker** for using RustDesk as a reliable unattended access solution on GNOME/Wayland-based NixOS systems. The security model of Wayland and GNOME's `xdg-desktop-portal` seems to fundamentally prevent a background service from capturing the screen without explicit user consent, even when running as root.