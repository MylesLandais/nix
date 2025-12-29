---
description: Apply NixOS rebuild to live system (requires /nix-check pass first)
allowed-tools: Bash
---

# nix-switch: Apply Rebuild

Apply validated changes to the live system. Only run after /nix-check passes.

## Prerequisites

/nix-check has been run and all phases passed. All errors resolved. Dry-run test completed successfully. User has committed changes to git.

## Execution

Ask user for explicit confirmation: "Ready to apply live system rebuild with nixos-rebuild switch. Confirm? (yes/no)"

If user confirms, run: sudo nixos-rebuild switch --flake /home/warby/Workspace/nix#cerberus --show-trace -L

## What Happens

System rebuilds with new configuration. Home-manager configuration is applied (updates ~/.config/ files and user packages). All changes take effect immediately or at next login (depending on service type).

## Success

Rebuild completes without errors. Report success. Suggest user test new functionality (e.g., if you changed git config, test git operations). If uncommitted changes remain, offer to help commit.

## Failure

If rebuild fails: Look at error output. First error in output is usually the root cause (not the last one). Common failures: Configuration syntax error (should have been caught by /nix-check; run it again). Build failure in a package (missing dependency or broken package in nixpkgs). Module option not recognized (typo or invalid option in configuration).

If rebuild fails: Suggest running /nix-check again to isolate issue. If flake check passed but rebuild fails, something changed in nixpkgs. Can try nix flake update to get latest package versions, then /nix-check again.

## Post-Rebuild Steps

Test changes: If modified git config, run git status to verify. If added package, run the program. If changed shell settings, restart shell with exec fish.

Environment variables: If changed environment variables or PATH, restart shell with exec fish.

Services: If changed a system service, service should auto-restart. If not, can manually systemctl restart service-name.

## Rollback (if needed)

If rebuild introduced a breaking change, NixOS keeps previous generations. Run: sudo nixos-rebuild switch -p 1 to roll back to previous generation. Then debug the issue and try again.

## If Rebuild Hangs

Ctrl+C to stop. Check system for obvious issues (disk full, network down). Retry rebuild. If persistent, may need to update flake: nix flake update
