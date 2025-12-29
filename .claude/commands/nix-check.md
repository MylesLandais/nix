---
description: Validate Nix configuration—syntax, formatting, linting, and dry-run test
allowed-tools: Bash
---

# nix-check: Comprehensive Validation

Run all validation and testing checks before applying changes. This catches errors before they reach the live system.

## Execution

Run these commands in sequence:

nix flake check --show-trace
nix fmt -- --check .
statix check .
sudo nixos-rebuild dry-activate --flake .# --show-trace -L

## Reporting Results

Phase 1 (Syntax Check): If nix flake check fails, stop and report all errors. Include file path and line number for each error.

Phase 2 (Format Check): If nix fmt fails, it's cosmetic. Safe to ignore for builds but should be fixed. Run nix fmt (without --check) to auto-fix formatting.

Phase 3 (Linting): Statix warnings (W20, etc.) are code quality suggestions, not blockers. Safe to skip if time critical.

Phase 4 (Dry-Run Build): If dry-run fails, report the build error. Look for the first error in output (not the last one). Error usually shows which file and line failed.

All four pass: State "All validation passed. Ready for /nix-switch"

Any phase fails: List errors with file paths. Suggest fixes based on error type.

## Error Interpretation

attribute 'X' missing: Package X doesn't exist or has a typo. Check nixpkgs documentation or search: nix search nixpkgs X

syntax error near X: Nix syntax problem. Check brackets, semicolons, attribute names at that line and surrounding lines.

infinite recursion: Circular dependency in attribute definitions. Check for self-references.

Read-only file system: Trying to edit /nix/store file. Changes must be in source .nix file (not the symlink target).

## What Gets Validated

Nix flake structure and attribute names. Syntax correctness across all .nix files. Code formatting consistency. Build-time issues (missing packages, invalid config options). Dry-run verifies the entire system would build without errors.

## If Dry-Run Takes Too Long

Ctrl+C to stop. Dry-run is comprehensive so it takes time. Can be skipped in development iteration but should always run before final /nix-switch.

## Next Steps

All phases pass: Ready for /nix-switch to apply changes to live system.

Errors: Fix in appropriate .nix file. Re-run /nix-check. Repeat until clean.
