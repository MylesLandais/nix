# Firefox Configuration Fix Guide

## Overview

This document explains the fixes applied to resolve NixOS/Home Manager evaluation warnings related to Firefox configuration.

## Issues Fixed

### 1. Search Engine ID References

**Problem**: Firefox search engines were referenced by display names instead of IDs, causing warnings like:
```
Search engines are now referenced by id instead of by name, use 'ddg' instead of 'DuckDuckGo'
```

**Solution**: Updated all search engine references to use proper IDs:

| Old Name | New ID |
|----------|--------|
| "DuckDuckGo" | "ddg" |
| "Google" | "google" |
| "Nix Packages" | "nix-packages" |
| "NixOS Options" | "nixos-options" |
| "Home Manager Options" | "home-manager" |

### 2. Deprecated iconUpdateURL Usage

**Problem**: Used deprecated `iconUpdateURL` attribute, causing warnings:
```
'iconUpdateURL' is deprecated, use 'icon = "https://example.com/favicon.ico"' instead
```

**Solution**: Replaced all `iconUpdateURL` with `icon` attribute:

```nix
# Before (deprecated)
"DuckDuckGo" = {
  urls = [{ template = "https://duckduckgo.com/?q={searchTerms}"; }];
  iconUpdateURL = "https://duckduckgo.com/favicon.ico";
  definedAliases = [ "@d" ];
};

# After (fixed)
"ddg" = {
  urls = [{ template = "https://duckduckgo.com/?q={searchTerms}"; }];
  icon = "https://duckduckgo.com/favicon.ico";
  definedAliases = [ "@d" ];
};
```

### 3. Default Search Engine Reference

**Problem**: `search.default` was set to display name instead of engine ID.

**Solution**: Updated to use engine ID:
```nix
search = {
  force = true;
  default = "ddg";  # Changed from "DuckDuckGo"
  # ... rest of config
};
```

### 4. Infinite Recursion Issue

**Problem**: The Firefox module was creating a circular reference by setting `programs.firefox.enable = true;` within itself.


### 5. Missing Firefox Enable Declaration

**Problem**: When removing duplicate configuration from `home.nix`, the `programs.firefox.enable = true;` declaration was accidentally removed, causing Firefox to not be installed or available in the run menu.

**Solution**: Added `programs.firefox.enable = true;` to the `programs` section in `home.nix` to ensure Firefox is properly enabled while maintaining the modular configuration structure.

### 6. Extension Availability Issues

**Problem**: Some Firefox extensions (`https-everywhere`, `decentraleyes`) were not available in the NUR repository, causing build failures.

**Solution**: Removed unavailable extensions from the configuration, keeping only the ones that are actually available:
- `ublock-origin`
- `bitwarden`
- `plasma-integration`
- `darkreader`
- `privacy-badger`

### 7. Bitwarden Toolbar and Private Window Issues

**Problem**: Bitwarden extension was not appearing in toolbar and not configured to run in private windows.

**Solution**: Added Bitwarden-specific Firefox preferences to ensure proper functionality:
```nix
# Bitwarden specific settings
"browser.nativeMessaging.bitwarden" = true;
"extensions.bitwarden@browser.duckduckgo.com.private" = true;
"extensions.bitwarden@browser.duckduckgo.com.toolbar" = true;
```
- `noscript`
**Solution**: Removed the redundant `enable = true;` line from the module configuration since the module is already conditional on `cfg.enable`.

## Configuration Structure

### Modular Approach

The Firefox configuration is now properly modularized:

1. **Main Module**: [`modules/firefox.nix`](../modules/firefox.nix)
   - Contains all Firefox settings
   - Defines custom options for preferences
   - Properly structured to avoid circular references

2. **Home Manager Integration**: [`home.nix`](../home.nix)
   - Imports the Firefox module
   - No duplicate Firefox configuration
   - Clean separation of concerns

### Key Features

The fixed configuration includes:

- **Privacy-focused settings**: Tracking protection, anti-fingerprinting
- **Security enhancements**: TLS settings, certificate validation
- **Performance optimizations**: Memory caching, hardware acceleration
- **Custom search engines**: DuckDuckGo, Google, Nix packages/options, Home Manager options
- **Extension management**: Privacy Badger, uBlock Origin, Bitwarden, etc.
- **UI customization**: Dark theme, vertical tabs, Kanagawa theme

## Firefox 136 Vertical Tabs Configuration

### Issue with Previous Configuration

The previous Firefox configuration was using incorrect preference names for enabling vertical tabs:

```nix
# INCORRECT - These preferences don't exist or don't work for vertical tabs
"reader.toolbar.vertical" = true;
"firefox.tabs.show-newtab-vertical" = true;
"firefox.tabs.vertical" = true;
```

### Correct Firefox 136 Vertical Tabs Configuration

Firefox 136 introduced vertical tabs as an experimental feature that requires specific preference flags:

```nix
# CORRECT - Firefox 136 vertical tabs preferences
"sidebar.revamp" = true;                    # Enable sidebar revamp (required)
"sidebar.verticalTabs" = true;              # Enable vertical tabs feature
"sidebar.main.tools" = "verticaltabs";      # Set vertical tabs as main sidebar tool
"sidebar.position_start" = true;            # Position sidebar on the left (optional)
```

### Implementation Steps

1. **Enable the sidebar revamp feature**: This is the foundation for the new vertical tabs
2. **Enable vertical tabs specifically**: This activates the vertical tabs functionality
3. **Set vertical tabs as the default sidebar tool**: This ensures vertical tabs are shown by default
4. **Configure sidebar position** (optional): Control whether tabs appear on left or right

### Complete Updated Configuration

Replace the incorrect tab configuration in [`modules/firefox.nix`](../modules/firefox.nix) with:

```nix
# Tab configuration - tabs on the left (Firefox 136 vertical tabs)
"sidebar.revamp" = true;                    # Enable sidebar revamp
"sidebar.verticalTabs" = true;              # Enable vertical tabs
"sidebar.main.tools" = "verticaltabs";      # Set vertical tabs as main sidebar tool
"sidebar.position_start" = true;            # Position sidebar on the left
```

### Verification

After applying the updated configuration:

1. Restart Firefox
2. Right-click on the tab bar area
3. Select "Toggle Sidebar" → "Vertical Tabs" or use Ctrl+B to toggle the sidebar
4. Tabs should now appear vertically in the left sidebar

### Troubleshooting

If vertical tabs still don't appear:

1. Check Firefox version: `firefox --version` (should be 136+)
2. Verify preferences are set: Visit `about:config` and search for `sidebar.verticalTabs`
3. Try manually enabling: In `about:config`, set `sidebar.revamp` and `sidebar.verticalTabs` to `true`
4. Restart Firefox after changing preferences

## Testing

### Validation Script

A comprehensive test script is available at [`scripts/firefox-config-test.sh`](../scripts/firefox-config-test.sh) that:

1. Checks basic syntax evaluation
2. Tests Home Manager integration
3. Validates no evaluation warnings are present
4. Confirms all deprecated attributes are removed

### Running Tests

```bash
# Make the script executable
chmod +x scripts/firefox-config-test.sh

# Run the tests
./scripts/firefox-config-test.sh
```

## Applying Changes

To apply the fixed Firefox configuration:

```bash
# If using Home Manager standalone
home-manager switch

# If using Home Manager as NixOS module
sudo nixos-rebuild switch
```

## Verification

After applying the changes, you should see:

1. **No evaluation warnings** related to Firefox configuration
2. **Proper search engine functionality** with all custom engines working
3. **Correct icons** for all search engines
4. **All extensions** properly installed and configured

## Troubleshooting

### Common Issues

1. **Build fails with infinite recursion**
   - Ensure the Firefox module doesn't set `enable = true` within itself
   - Check for circular references in module definitions

2. **Search engines not appearing**
   - Verify engine IDs are unique and properly formatted
   - Check that `search.default` matches one of the defined engine IDs

3. **Icons not loading**
   - Ensure all `iconUpdateURL` have been replaced with `icon`
   - Verify icon URLs are accessible

### Debug Commands

```bash
# Check Firefox configuration evaluation
nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; lib = pkgs.lib; cfg = { programs.firefox.enable = true; programs.firefox.preferences = {}; }; in (import ./modules/firefox.nix { config = cfg; inherit lib pkgs; })'

# Test full Home Manager configuration
nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; lib = pkgs.lib; in (import ./home.nix { inherit pkgs lib; vars = { username = "test"; }; config = {}; inputs = {}; self = {}; })'
```

## Future Maintenance

When updating Firefox configuration in the future:

1. **Always use engine IDs** instead of display names
2. **Use `icon` attribute** instead of `iconUpdateURL`
3. **Test changes** with the provided validation script
4. **Keep modular structure** to avoid duplication

## References

- [Home Manager Firefox Options](https://home-manager-options.extranix.com/?query=firefox)
- [NixOS Firefox Configuration](https://nixos.org/manual/nixos/stable/options.html#opt-programs.firefox)
- [Firefox Search Engine Configuration](https://support.mozilla.org/en-US/kb/add-or-remove-search-engine-firefox)