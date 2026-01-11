# NixOS Configuration Style Guide

This document extends the global Claude Code rules with Nix-specific guidance.

## Nix Development Workflow

All changes follow this sequence: Edit, Validate with /nix-check, Commit, Apply with /nix-switch

Do not skip /nix-check. Do not commit unvalidated changes. Do not apply changes to live system without validation.

## Where to Make Changes

System configuration (kernel, boot, security, hardware, firewall, services): hosts/cerberus/configuration.nix

User environment (shell, git config, dotfiles, programs): home.nix or devtooling/ modules

Development tools (git, claude-code, remmina, etc.): devtooling/TOOLNAME/default.nix

Desktop environment (Hyprland, keybinds, panels): hypr.nix, hyprpanel.nix

System packages available globally: environment.systemPackages in hosts/cerberus/configuration.nix

User packages and dotfiles: home.packages or home.file in home.nix

Shell functions and aliases: devtooling/shelltools/ (automatically imported)

## Common Procedures

### Add a System Package

Edit hosts/cerberus/configuration.nix. Find environment.systemPackages section. Add package name to list. Run /nix-check. If error "attribute missing", package doesn't exist in nixpkgs; search with nix search nixpkgs package-name. Commit with chore(packages): add package-name. Run /nix-switch.

### Add User Program or Dotfile

Edit home.nix. Find home.packages section or create home.file entry for dotfiles. Use proper XDG paths for config files. Run /nix-check. If home-manager syntax error, error message shows file and line number. Commit appropriately. Run /nix-switch.

Important: Do NOT run home-manager switch alone. Always use nixos-rebuild switch which handles both system and home-manager.

### Update Git Configuration

Edit devtooling/git/default.nix. Find programs.git.settings section. Add or modify setting. Run /nix-check. Commit with chore(git): add or update setting_name. Run /nix-switch.

Git config file at ~/.config/git/config is read-only (symlink to /nix/store). All changes must be in devtooling/git/default.nix. Verify changes after rebuild with cat ~/.config/git/config or git config --global key_name.

### Add Passwordless Sudo Rule

Edit hosts/cerberus/configuration.nix. Find security.sudo.extraRules section. Add new rule with command path and NOPASSWD option. Use /run/current-system/sw/bin/command for paths (not ${pkgs.command}). Run /nix-check. Commit with chore(sudo): add NOPASSWD for command_name. Run /nix-switch.

### Fix Build Errors After /nix-check

Read error message and note file path and line number. Common errors: "attribute X missing" means typo or package doesn't exist. "syntax error" means Nix syntax issue, check brackets and semicolons. "infinite recursion" means circular dependency. "Read-only file system" means trying to edit /nix/store; change the .nix source instead. Fix the issue. Run /nix-check again. Repeat until all phases pass.

### Handle Home-Manager Configuration Not Applying

Changes to home.nix or devtooling/ should appear in ~/.config files after rebuild. If not: Verify rebuild ran by checking target file. If file is old, rebuild didn't apply. Cause is usually running home-manager switch instead of nixos-rebuild switch. Run: sudo nixos-rebuild switch --flake /home/warby/Workspace/nix#cerberus. Wait for completion. Check file again. If still missing, check module imports in home.nix and devtooling/default.nix. If still failing, run /nix-check for validation errors.

### Shell Not Seeing Changes

Changes to environment, PATH, or other shell variables need shell restart. Verify changes applied by checking config file or running git config --global credential.helper. Restart current shell with exec fish (or bash). Test command again. If still old values, reboot: sudo reboot.

Opening a new terminal window does NOT reload environment. Must restart the current shell with exec.

## Task Completion Pattern

After completing work:

Report completion status plainly. Include work summary. Verify changes are tracked in git. Report files modified or deployed. Confirm validation and rebuilds passed.

Verification examples: Git (commit hash, staging status). Nix (validation passed, rebuild succeeded, symlinks confirmed). System (functionality tested, services running).

## Resources

Nix Manual: https://nixos.org/manual/nix/stable/
NixOS Manual: https://nixos.org/manual/nixos/stable/
Home Manager Manual: https://home-manager-options.extranix.com/
NixOS & Flakes Book: https://nixos-and-flakes.thiscute.world/
Statix: https://github.com/nix-community/statix
Hyprland: https://wiki.hyprland.org/
Fish Shell: https://fishshell.com/docs/current/
Conventional Commits: https://www.conventionalcommits.org/

When troubleshooting: Check NixOS Manual for module options. Check nixpkgs source for package names. Search NixOS Discourse or GitHub issues for build errors. Check official docs for language-specific config (fish, hyprland).
