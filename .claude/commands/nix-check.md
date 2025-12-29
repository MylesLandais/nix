---
description: Validate Nix configuration—syntax, formatting, linting, and dry-run test
allowed-tools: Bash
---

# nix-check: Comprehensive Validation

Run all validation and testing checks before applying changes to the live system. This catches errors quickly for fast debug and triage.

## Validation Phases

Execute in sequence and report results:

### Phase 1: Syntax and Format
```bash
nix flake check --show-trace
nix fmt -- --check .
```

### Phase 2: Code Quality Linting
```bash
statix check .
```

### Phase 3: Dry-Run Build Test
```bash
sudo nixos-rebuild dry-activate --flake .# --show-trace -L
```

## Reporting Results

After each phase completes:

- **Phase 1 (Syntax/Format)**: If fails, stop and report all errors with file paths and line numbers
- **Phase 2 (Linting)**: Report all statix warnings; these are fixable with `/nix-fix` if needed
- **Phase 3 (Dry-Run)**: If successful, state "Dry-run passed. Ready for /nix-switch"
- **If any phase fails**: List errors clearly, explain them, suggest fixes

## What This Checks

- Nix syntax correctness
- Code formatting consistency
- Antipatterns and inefficiencies (unused variables, missing inherits, etc.)
- Build validity without applying changes

## Next Steps

- **If all pass**: User can run `/nix-switch` to apply changes live
- **If linting fails but build passes**: User can run `/nix-fix` to auto-correct, then re-run `/nix-check`
- **If build fails**: Diagnose error, propose fixes, iterate
