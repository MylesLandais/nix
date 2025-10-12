# NixOS Config History

## 2025-10-12
- Fixed Brave browser crashes on dell-potato host (Intel integrated + AMD discrete GPU, GNOME desktop).
- Added hardware acceleration configuration with VA-API drivers for hybrid graphics setup.

## 2025-10-09
# NixOS Config History

## 2025-10-09
- Generated a system information report for the `dell-potato` host.
- Created and debugged a shell script (`generate_report.sh`) to collect hardware, driver, and encoding details.
- Resolved execution issues on NixOS by correcting the shebang from `#!/bin/bash` to `#!/usr/bin/env bash` and finally executing with `bash ./generate_report.sh` to ensure the correct interpreter.
- Appended the generated report to `hosts/dell-potato/etc/nixos/README.md` for documentation.
- Staged and committed the changes with a detailed message outlining the process.

## 2025-10-05
- Resolved code-server Docker image build failures by removing custom image derivation (avoiding VM space issues) and using base codercom/code-server:latest.
- Added self-signed SSL certificate generation in system activation script for HTTPS support.
- Configured code-server container for HTTPS with cert and key files.
- Pre-installed Tokyo Night theme via activation script in persistent volume.
- Manually installed Tokyo Night extension after container startup.
- Updated dev-health-check.sh to detect custom vs. base image, SSL certificate presence, and HTTPS accessibility.
- Fixed container startup issues by simplifying cmd to standard flags.
- Reset Portainer admin password to 'devsandbox123' for consistency with other services, using API initialization after data reset.
- Optimized disk space by removing unused Docker images (jupyter/scipy-notebook, jupyter/minimal-notebook, linuxserver/code-server) and running Nix garbage collection on old system generations.
- Tuned Nix build performance with max-jobs=4, cores=4, added Chaotic substituter, enabled sandbox and auto-optimise-store; commented out problematic jupyter and livebook containers to resolve build issues.

## 2025-10-04
- Integrated Brave browser via Home Manager with extensions: Shazam (akibfjgmcjogdlefokjmhblcibgkndog), Kanagawa Theme (cjlbjibclmofpebnmgibklnkhhjlbjgc), Bitwarden (nngceckbapebfimnlniiiahkandclblb).
- Set Brave as default browser in xdg.mimeApps.
- Enabled Stylix GTK theming for Kanagawa dark mode system-wide.
- Added --enable-features=WebUIDarkMode flag to Brave for UI dark mode.
- Created rebuild-clean.sh script to handle common rebuild conflicts (Chromium lock, GTK backups).
- Fixed Home Manager integration in flake.nix with backupFileExtension for theming.
- Removed conflicting nixpkgs.config from home.nix.
- Added brave package to home.nix packages for installation.