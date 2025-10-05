# NixOS Config History

## 2025-10-05
- Resolved code-server Docker image build failures by removing custom image derivation (avoiding VM space issues) and using base codercom/code-server:latest.
- Added self-signed SSL certificate generation in system activation script for HTTPS support.
- Configured code-server container for HTTPS with cert and key files.
- Pre-installed Tokyo Night theme via activation script in persistent volume.
- Manually installed Tokyo Night extension after container startup.
- Updated dev-health-check.sh to detect custom vs. base image, SSL certificate presence, and HTTPS accessibility.
- Fixed container startup issues by simplifying cmd to standard flags.

## 2025-10-04
- Integrated Brave browser via Home Manager with extensions: Shazam (akibfjgmcjogdlefokjmhblcibgkndog), Kanagawa Theme (cjlbjibclmofpebnmgibklnkhhjlbjgc), Bitwarden (nngceckbapebfimnlniiiahkandclblb).
- Set Brave as default browser in xdg.mimeApps.
- Enabled Stylix GTK theming for Kanagawa dark mode system-wide.
- Added --enable-features=WebUIDarkMode flag to Brave for UI dark mode.
- Created rebuild-clean.sh script to handle common rebuild conflicts (Chromium lock, GTK backups).
- Fixed Home Manager integration in flake.nix with backupFileExtension for theming.
- Removed conflicting nixpkgs.config from home.nix.
- Added brave package to home.nix packages for installation.