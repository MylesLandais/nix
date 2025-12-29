---
description: Apply NixOS rebuild to live system (requires /nix-check pass first)
allowed-tools: Bash
---

# nix-switch: Apply Rebuild

Apply the validated Nix configuration changes to the live system. Only run after `/nix-check` passes successfully.

## Prerequisites

Before running this command, ensure:

1. `/nix-check` has been run and all phases passed
2. All errors and linting issues have been resolved
3. Dry-run test completed successfully

## Execution

If prerequisites are met, ask user for explicit confirmation:

> "Ready to apply live system rebuild with `nixos-rebuild switch`. Confirm? (yes/no)"

If user confirms, run:

```bash
sudo nixos-rebuild switch --flake .# --show-trace -L
```

## Success Handling

After rebuild completes successfully:

- Report success with system state confirmation
- Suggest user test system functionality
- Offer to commit changes if user has uncommitted modifications

## Failure Handling

If rebuild fails:

- Report all error output with full traces
- Do NOT attempt automatic recovery
- Suggest running `/nix-check` again to isolate the issue
- Provide debugging hints based on error type

## Safety Gates

This command requires:
- Explicit user confirmation before execution
- Prior successful `/nix-check` run
- Rebuild to be tested via dry-run before this step
