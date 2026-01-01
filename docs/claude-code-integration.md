# Claude Code Integration

## Overview

This configuration adds Anthropic's Claude Code CLI tool to your NixOS setup using a declarative, flake-based approach with automatic updates via the `sadjow/claude-code-nix` community flake.

## Changes Made

### 1. Added flake input
- Added `claude-code.url = "github:sadjow/claude-code-nix";` to `flake.nix`
- This provides auto-updated Claude Code packages that track upstream npm releases hourly

### 2. Added overlay
- Added `inputs.claude-code.overlays.default` to the pkgs overlay list in `flake.nix`
- This makes `pkgs.claude-code` available throughout the system

### 3. Created devtooling module
- Created `devtooling/claude-code/default.nix` following your existing pattern
- Module provides `claude-code.enable` option (enabled by default)

### 4. Updated devtooling
- Added claude-code to imports in `devtooling/default.nix`
- Set `claude-code.enable = lib.mkDefault true;`

### 5. Updated agenix for secrets
- Added `anthropic-api-key` secret to `modules/agenix.nix`
- Secret file: `secrets/anthropic-api-key.age`
- Owner: `warby`

### 6. Updated session variables
- Added `ANTHROPIC_API_KEY = "$ANTHROPIC_API_KEY";` to `home.nix` session variables

### 7. Fixed Ghostty Shift+Enter keybinding
- Added `keybind = shift+enter=send_text:\\n` to Ghostty config in `home.nix`
- This resolves the "Failed to install Ghostty Shift+Enter key binding" error during Claude Code terminal setup
- Enables multi-line prompts in Claude Code using Shift+Enter instead of immediately sending messages

## Setup Instructions

### 1. Generate and encrypt your API key

First, get your Anthropic API key from https://console.anthropic.com/settings/keys

Then encrypt it using agenix:

```bash
# Create a temporary file with your API key
echo "sk-ant-your-api-key-here" > /tmp/anthropic-api-key

# Encrypt it
cd /home/warby/Workspace/nix
agenix -e secrets/anthropic-api-key.age

# Clean up
rm /tmp/anthropic-api-key
```

### 2. Apply the configuration

```bash
sudo nixos-rebuild switch --flake .#cerberus
```

### 3. Verify installation

After rebuilding, you should be able to run:

```bash
claude --version
```

### 4. Initial configuration

The first time you run `claude`, it will ask you to authenticate. Since we're using an API key via environment variable, you can skip the interactive login.

To test:

```bash
claude "Hello, can you help me with something?"
```

## IDE Integration

### VSCode
1. Install the "Claude Code" extension from the marketplace (publisher: anthropic)
2. Run `claude` in VSCode's integrated terminal for auto-setup

### Cursor
1. Cursor has official support for Claude Code
2. Install the same extension via marketplace
3. Run `claude` in Cursor's terminal for auto-setup

### Zed
1. No native extension yet - use the CLI in Zed's integrated terminal
2. Run `claude` in the terminal for full CLI functionality

## Secret Management Note

The `ANTHROPIC_API_KEY` is set in session variables but references an environment variable that needs to be loaded from the encrypted secret. You may need to add a systemd service or shell initialization to load the secret from `/run/agenix/anthropic-api-key` into your session.

For a simpler setup, you can also:

1. Add the API key directly to your shell's `.env` or `.profile` (not recommended for security)
2. Use `direnv` with `.envrc` files for project-specific keys
3. Use a credential manager like `pass` or `bitwarden-cli` to inject the key

## Benefits of This Approach

- **Declarative**: Everything is defined in Nix, not via npm global installs
- **Reproducible**: Same configuration across all your machines
- **Auto-updating**: Community flake tracks upstream releases hourly
- **Secure**: API keys managed via agenix encryption
- **Modular**: Follows your existing devtooling pattern

## Troubleshooting

### Claude not found after rebuild
Run `hash -r` to refresh your shell's path cache, or restart your shell.

### API key not working
Verify the secret was decrypted properly:
```bash
cat /run/agenix/anthropic-api-key
```

### Version outdated
The sadjow flake auto-updates hourly. To force an update:
```bash
nix flake update --commit-lock-file claude-code
sudo nixos-rebuild switch --flake .#cerberus
```

### Ghostty Shift+Enter keybinding error
**Error**: "Failed to install Ghostty Shift+Enter key binding" when running Claude Code terminal setup

**Cause**: Claude Code's `/terminal-setup` cannot reliably modify Ghostty's configuration on NixOS due to immutable filesystem and config format differences.

**Resolution**: This has been fixed declaratively in your configuration. The keybinding is now managed via NixOS:
```nix
keybind = shift+enter=send_text:\\n
```

**Usage**:
- Press **Enter** to send your message to Claude
- Press **Shift+Enter** to insert a newline for multi-line prompts

**Verification**:
```bash
cat ~/.config/ghostty/config | grep keybind
```

If the keybinding doesn't appear, rebuild:
```bash
sudo nixos-rebuild switch --flake .#cerberus
```
Then restart Ghostty to apply changes.

**Alternative**: If you prefer manual setup, add this directly to `~/.config/ghostty/config`:
```
keybind = shift+enter=send_text:\n
```

## Alternative: Using nixpkgs package

If you prefer the official nixpkgs package (though it may lag behind), you can:

1. Remove the claude-code flake input from `flake.nix`
2. Remove the overlay
3. Change `devtooling/claude-code/default.nix` to use `pkgs.claude-code` directly from nixpkgs

This requires nixpkgs unstable channel and `allowUnfree = true` (which you already have).
