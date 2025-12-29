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

## Nix Development Validation Rules (MANDATORY)

When modifying any .nix files, flake.nix, flake.lock, or home-manager configuration:

### Before Committing

YOU MUST run `/nix-check` to validate all changes:

1. Syntax and formatting validation (`nix flake check`, `nix fmt`)
2. Code quality linting (`statix check`)
3. Dry-run rebuild test (`nixos-rebuild dry-activate --show-trace`)

If `/nix-check` reports errors:
- Analyze each error with file path and line number
- Propose precise fixes
- Apply fixes and re-run `/nix-check`
- Repeat until all checks pass
- NEVER commit unvalidated Nix changes

### Applying Changes to Live System

After `/nix-check` passes, use `/nix-switch` to apply changes:

1. Requires explicit user confirmation
2. Tests changes on live system
3. Rolls back automatically if it detects failures

### Validation Workflow

```
Modify .nix file(s)
         ↓
    /nix-check (syntax, format, lint, dry-run)
         ↓
    Fix any errors and re-run /nix-check
         ↓
    All checks pass?
         ↓
    git commit (with proper conventional commits message)
         ↓
    /nix-switch (apply live rebuild with confirmation)
```

### Integration with Version Control

- NEVER propose commits for unvalidated Nix changes
- Always include explanation of "why" in commit body if changes are substantial
- Use scopes like `feat(hyprland)`, `fix(git)`, `chore(deps)` to indicate affected modules
- Reference validation results in commit context when resolving complex issues

This ensures stable builds and maintainable configurations.
