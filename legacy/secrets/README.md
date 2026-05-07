# Anthropic API Key

This directory contains encrypted secrets managed by agenix.

## Required for Claude Code

Generate your API key from: https://console.anthropic.com/settings/keys

Then encrypt it:

```bash
echo "sk-ant-your-actual-api-key-here" | agenix -e secrets/anthropic-api-key.age
```

## Current Secrets

- `tailscale-auth-key.age` - Tailscale authentication key
- `code-server-password.age` - Code server password
- `ollama.age` - Ollama API configuration
- `anthropic-api-key.age` - Anthropic API key for Claude Code

## Security Note

Never commit actual secret values to git. The `.age` files are the only files that should be in this directory.
