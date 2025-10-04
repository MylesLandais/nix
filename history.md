# NixOS Config History

## 2025-10-04
- Integrated Brave browser via Home Manager with extensions: Shazam (akibfjgmcjogdlefokjmhblcibgkndog), Kanagawa Theme (cjlbjibclmofpebnmgibklnkhhjlbjgc), Bitwarden (nngceckbapebfimnlniiiahkandclblb).
- Set Brave as default browser in xdg.mimeApps.
- Enabled Stylix GTK theming for Kanagawa dark mode system-wide.
- Added --enable-features=WebUIDarkMode flag to Brave for UI dark mode.
- Created rebuild-clean.sh script to handle common rebuild conflicts (Chromium lock, GTK backups).
- Fixed Home Manager integration in flake.nix with backupFileExtension for theming.
- Removed conflicting nixpkgs.config from home.nix.
- Added brave package to home.nix packages for installation.