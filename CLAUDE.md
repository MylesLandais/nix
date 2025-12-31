# Claude Code Style Guide

This document defines standards for all Claude Code interactions in this repository.

## Commit Message Guidelines (MANDATORY)

Commits MUST follow the [Conventional Commits Specification](https://www.conventionalcommits.org/).

### Structure

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type

Required prefix indicating the nature of changes:

- `feat`: Introduces a new feature (correlates with MINOR in Semantic Versioning)
- `fix`: Patches a bug (correlates with PATCH in Semantic Versioning)
- `docs`: Documentation-only changes
- `style`: Changes that do not affect the meaning of code (formatting, missing semicolons, etc.)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or dependencies
- `chore`: Other changes that don't modify src or test files (e.g., build config, package updates)
- `ci`: Changes to CI/CD configuration files and scripts

### Scope (Optional)

Contextual information in parentheses indicating what part of the codebase is affected:
- Examples: `feat(hyprland)`, `fix(syncthing)`, `chore(deps)`

### Description

- Mandatory short summary after the colon and space
- Concise, under 72 characters
- Use imperative mood ("add" not "added")
- No trailing period
- Lowercase after colon

### Body (Optional)

- Separated from description by a blank line
- Explain the motivation and what is being changed (the "why"), not the "what"
- Include any breaking change information if applicable

### Breaking Changes

Indicate breaking changes with `!` before the colon:

```
feat(api)!: restructure authentication flow
```

Or use a footer:

```
BREAKING CHANGE: authentication tokens now require rotation every 30 days
```

### General Rules

- NEVER use emojis, bullet points, numbered lists, or superfluous formatting
- NEVER include AI attribution, decorations, or "Generated with" text
- Single-line commits are preferred for simple changes
- Multi-line commits only when explaining complex "why" context

## Examples

### Good Commits

```
feat: add DPMS monitor script for Hyprland reload
```

```
feat(syncthing): add Obsidian vault sync configuration

Configure automatic file synchronization between Cerberus and Hydra server
with iPad as secondary device. Enable filesystem watching for responsive sync.
```

```
fix(ghostty): correct keybind escape sequence

Resolve issue where Shift+Enter was not properly sending newline character
due to double-escaped backslash in keybind configuration.
```

```
docs: add conventional commits style guide
```

```
refactor(home-manager): simplify theme configuration
```

### Bad Commits

```
add cool new features  # Missing type, unclear scope
```

```
🎉 feat: add awesome sauce emoji  # Contains emoji, vague description
```

```
feat: add new feature

- Added feature A
- Added feature B
- Also fixed thing C  # Bullet points, multiple concerns mixed
```

```
feat: add syncthing

This commit adds syncthing integration. We added syncthing because we needed
to sync files. It syncs files between devices. Now files are synced.  # Redundant "what", missing "why"
```

## Claude Code Response Format (MANDATORY)

All Claude Code responses to the user MUST follow these rules:

- NEVER use emojis (no ✓, ✅, ⚠️, 🎉, etc.)
- NEVER use bullet points or numbered lists for general text
- NEVER use bold, italics, or other decorative formatting
- NEVER use checkmarks, arrows, or other visual decorations
- Keep responses brief and direct
- Use plain text with line breaks for separation
- Code blocks and command examples are acceptable

Bad: "✅ Phase 1 passed successfully. **Ready for Phase 2:**"
Good: "Phase 1 passed. Ready for Phase 2."

Bad: "Here are the steps:
1. Run nix check
2. Fix errors
3. Commit"
Good: "Run nix check. Fix any errors. Then commit."

## General Guidelines

Keep explanations brief and focused on implementation rationale. Prioritize clarity over completeness in all written content. When in doubt, prefer fewer words over more explanation. Reference the [Conventional Commits Specification](https://www.conventionalcommits.org/) for edge cases.

## Documentation Standards (MANDATORY)

File naming rules:
- NEVER use ALL CAPS filenames (README.md, CHANGELOG.md, CONTRIBUTING.md, LICENSE.md)
- Use lowercase with hyphens: readme.md, changelog.md, contributing.md, license.md
- Prefer descriptive lowercase names: setup-guide.md, api-reference.md

Documentation creation rules:
- NEVER create documentation files unless explicitly requested by the user
- Do not proactively generate readme files, changelogs, or contributing guides
- Avoid cluttering repositories with boilerplate documentation
- If documentation is needed, keep it minimal and focused
- Prefer inline code comments over separate documentation files when appropriate
- Consolidate related documentation rather than creating multiple small files

Bad filenames: README.md, CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md
Good filenames: readme.md, changelog.md, contributing.md, security.md, code-of-conduct.md

## Nix Development Workflow

All changes follow this sequence: Edit → Validate with /nix-check → Commit → Apply with /nix-switch

Do not skip /nix-check. Do not commit unvalidated changes. Do not apply changes to live system without validation.

### Where to Make Changes

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

Edit home.nix. Find home.packages section or create home.file entry for dotfiles. Use proper XDG paths for config files. Run /nix-check. If home-manager syntax error, error message shows file and line number. Commit appropriately. Run /nix-switch (this applies home-manager changes).

Important: Do NOT run home-manager switch alone. Always use nixos-rebuild switch which handles both system and home-manager.

### Update Git Configuration

Edit devtooling/git/default.nix. Find programs.git.settings section. Add or modify setting (e.g., credential.helper, user.name). Run /nix-check. Commit with chore(git): add or update setting_name. Run /nix-switch.

Important: Git config file at ~/.config/git/config is read-only (symlink to /nix/store). All changes must be in devtooling/git/default.nix.

Verify changes: After rebuild, check with cat ~/.config/git/config or git config --global key_name

### Add Passwordless Sudo Rule

Edit hosts/cerberus/configuration.nix. Find security.sudo.extraRules section. Add new rule with command path and NOPASSWD option. For command path, use /run/current-system/sw/bin/command (not ${pkgs.command} which may not exist). Run /nix-check. If error "attribute missing", the package path syntax is wrong; use plain path instead. Commit with chore(sudo): add NOPASSWD for command_name. Run /nix-switch.

### Fix Build Errors After /nix-check

Read error message and note file path and line number. Common errors: "attribute X missing" means typo or package doesn't exist in nixpkgs. "syntax error" means Nix syntax issue, check brackets and semicolons. "infinite recursion" means circular dependency, check for self-references. "Read-only file system" means trying to edit /nix/store directly; change the .nix module source instead. Fix the issue. Run /nix-check again. Repeat until all phases pass.

### Handle Home-Manager Configuration Not Applying

Changes to home.nix or devtooling/ should appear in ~/.config files after rebuild. If not: Verify rebuild ran by checking target file (e.g., cat ~/.config/git/config). If file is old, rebuild didn't apply changes. Cause is usually running home-manager switch instead of nixos-rebuild switch. Run correct command: sudo nixos-rebuild switch --flake /home/warby/Workspace/nix#cerberus. Wait for rebuild to complete. Check file again. If still not there, check if module is imported in home.nix and devtooling/default.nix. If still failing, run /nix-check for validation errors.

### Shell Not Seeing Changes

Changes to environment, PATH, or other shell variables need shell restart. Verify changes applied: Check config file or run git config --global credential.helper. Restart current shell with exec fish (or bash). Test command again. If still old values, reboot: sudo reboot. After reboot, verify.

Important: Opening a new terminal window does NOT reload. Must restart the current shell with exec.

## Validation Rules (MANDATORY)

Always run /nix-check before committing Nix changes. Always run /nix-switch after committing to apply changes. Do not commit unvalidated changes. Do not apply changes without validation.

## Integration with Version Control

Commit messages follow Conventional Commits format. Explain the why for substantial changes. Use scopes like feat(hyprland), fix(git), chore(sudo) to indicate what changed. Reference validation passing in commit context if resolving complex issues.

## Task Completion Pattern

After completing a task (especially multi-step work like configuration changes):

Report completion status plainly. Include work summary describing what was changed. Verify changes are tracked in git with commit hash and log. Report any files modified or deployed. If validation or rebuilds ran, confirm they passed.

Offer continuity options using multiple choice questions. Each option should represent a distinct next action, not a phase continuation. Avoid "continue to phase 2" style prompts. Offer choices like: review specific aspect, test functionality, start a new task, or done.

Include verification steps. For Nix changes: Confirm nix-check passed, rebuild succeeded, and files deployed to expected locations. For git work: Show recent commits and verify files are staged. For system changes: Test the functionality that was modified.

Document patterns for future iterations. After complex tasks, consider what could improve the workflow. Update this CLAUDE.md with lessons learned, common gotchas, or new best practices discovered during execution. This ensures continuous improvement and helps future work avoid similar pitfalls.

Examples of completed verification:
- Git: commit hash, file changes, staging status
- Nix: validation phases passed, rebuild success, deployment symlinks confirmed
- System: functionality tested, services running, configuration applied to expected locations

## Documentation and Resources

Official references for understanding and debugging this configuration:

Nix Manual: https://nixos.org/manual/nix/stable/ Reference for Nix language, flakes, and command-line tools.

NixOS Manual: https://nixos.org/manual/nixos/stable/ System configuration, modules, and options.

Home Manager Manual: https://home-manager-options.extranix.com/ User environment configuration and available options.

NixOS Wiki - Declarative Package Management: https://nixos.wiki/wiki/Nixpkgs Practical guides for packages and modules.

NixOS & Flakes Book (Community Guide): https://nixos-and-flakes.thiscute.world/ Comprehensive introduction to flakes and modern Nix development.

Statix GitHub: https://github.com/nix-community/statix Nix linting tool documentation and available lints.

Hyprland Documentation: https://wiki.hyprland.org/ Window manager configuration for this system.

Fish Shell Manual: https://fishshell.com/docs/current/ Shell configuration and scripting for shell aliases and functions.

Git Documentation: https://git-scm.com/doc Git config options and credential systems.

Conventional Commits: https://www.conventionalcommits.org/ Commit message format specification (used in this repo).

When troubleshooting: Check the NixOS Manual for module options. Check nixpkgs source for package names and available variants. For build errors, search error message in NixOS Discourse or GitHub issues. For language-specific config (fish, hyprland, etc.), check official docs for that tool.
