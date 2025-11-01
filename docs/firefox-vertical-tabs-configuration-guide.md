# Firefox Vertical Tabs Configuration Guide

## Overview

This guide provides comprehensive instructions for enabling and configuring Firefox's native vertical tabs feature on NixOS using Home Manager. Firefox 136 and above includes native vertical tabs functionality that can be enabled through specific preferences.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Current Configuration Status](#current-configuration-status)
3. [Understanding Firefox Vertical Tabs](#understanding-firefox-vertical-tabs)
4. [Configuration Options](#configuration-options)
5. [Verification Steps](#verification-steps)
6. [Troubleshooting](#troubleshooting)
7. [Customization](#customization)
8. [Extension Compatibility](#extension-compatibility)
9. [Quick Reference](#quick-reference)

## Prerequisites

### Firefox Version Requirements

- **Firefox 136+**: Full native vertical tabs support
- **Firefox 125-135**: Limited experimental support
- **Firefox 124 and below**: No native vertical tabs (requires extensions)

Since this NixOS configuration uses the `nixos-unstable` channel, it will typically have the latest Firefox version with full vertical tabs support.

### NixOS/Home Manager Setup

Ensure your system has:
- NixOS with Home Manager configured
- Firefox enabled in your Home Manager configuration
- The Firefox module imported in your `home.nix`

## Current Configuration Status

The current configuration in [`modules/firefox.nix`](../modules/firefox.nix) already includes the correct preferences for Firefox 136+ vertical tabs:

```nix
# Tab configuration - tabs on the left (Firefox 136 vertical tabs)
"sidebar.revamp" = true;                    # Enable sidebar revamp
"sidebar.verticalTabs" = true;              # Enable vertical tabs
"sidebar.main.tools" = "verticaltabs";      # Set vertical tabs as main sidebar tool
"sidebar.position_start" = true;            # Position sidebar on the left
"sidebar.verticalTabs.width" = 200;         # Set explicit width for vertical tabs
"browser.tabs.inTitlebar" = 0;              # Move tabs out of titlebar
```

This configuration is already correct and should enable vertical tabs after applying the Home Manager configuration.

## Understanding Firefox Vertical Tabs

### How Vertical Tabs Work in Firefox 136+

Firefox 136 introduced a redesigned sidebar system that includes native vertical tabs. This feature consists of several components:

1. **Sidebar Revamp**: A new sidebar architecture that supports multiple tools
2. **Vertical Tabs**: Tab display in the sidebar instead of the top tab bar
3. **Sidebar Tools**: Different tools that can be displayed in the sidebar (bookmarks, history, vertical tabs)

### Key Preferences

| Preference | Type | Default | Description |
|------------|------|---------|-------------|
| `sidebar.revamp` | Boolean | false | Enables the new sidebar architecture (required for vertical tabs) |
| `sidebar.verticalTabs` | Boolean | false | Enables vertical tabs functionality |
| `sidebar.main.tools` | String | "" | Comma-separated list of tools to show in sidebar |
| `sidebar.position_start` | Boolean | true | Positions sidebar on the left (true) or right (false) |
| `sidebar.verticalTabs.width` | Integer | 200 | Width of the vertical tabs area in pixels |
| `browser.tabs.inTitlebar` | Integer | 1 | Controls tab bar placement (0 = hidden, 1 = in titlebar) |

## Configuration Options

### Basic Configuration

The minimal configuration required for vertical tabs:

```nix
{
  programs.firefox.profiles.default.settings = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
  };
}
```

### Recommended Configuration

The recommended configuration for optimal vertical tabs experience:

```nix
{
  programs.firefox.profiles.default.settings = {
    # Core vertical tabs settings
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
    "sidebar.main.tools" = "verticaltabs";
    "sidebar.position_start" = true;
    "sidebar.verticalTabs.width" = 200;
    
    # UI adjustments for vertical tabs
    "browser.tabs.inTitlebar" = 0;
    "browser.uidensity" = 0;  # Compact mode (optional)
  };
}
```

### Advanced Configuration

For users who want more control over the sidebar:

```nix
{
  programs.firefox.profiles.default.settings = {
    # Core vertical tabs settings
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
    "sidebar.main.tools" = "verticaltabs,bookmarks,history";
    "sidebar.position_start" = true;
    "sidebar.verticalTabs.width" = 250;
    
    # Tab behavior
    "browser.tabs.tabMinWidth" = 76;
    "browser.tabs.tabClipWidth" = 140;
    "browser.tabs.tabmanager.enabled" = false;
    
    # UI adjustments
    "browser.tabs.inTitlebar" = 0;
    "browser.uidensity" = 0;
  };
}
```

## Verification Steps

### 1. Apply Configuration

First, apply your Home Manager configuration:

```bash
home-manager switch
```

### 2. Check Firefox Version

Verify you have Firefox 136 or newer:

```bash
firefox --version
```

### 3. Verify Preferences in about:config

1. Open Firefox
2. Navigate to `about:config`
3. Search for the following preferences to verify they're set correctly:
   - `sidebar.revamp` should be `true`
   - `sidebar.verticalTabs` should be `true`
   - `sidebar.main.tools` should include `verticaltabs`

### 4. Enable Vertical Tabs in UI

If vertical tabs don't appear automatically:

1. Right-click on the tab bar area
2. Select "Toggle Sidebar" → "Vertical Tabs"
3. Or use the keyboard shortcut `Ctrl+B` to toggle the sidebar
4. Click the sidebar panel icon (if visible) and select "Vertical Tabs"

### 5. Test the Configuration Script

Run the provided test script to validate your configuration:

```bash
chmod +x scripts/firefox-config-test.sh
./scripts/firefox-config-test.sh
```

## Troubleshooting

### Vertical Tabs Not Appearing

#### Check Firefox Version
```bash
firefox --version
```
If you're not using Firefox 136+, update your system:
```bash
sudo nixos-rebuild switch --upgrade
```

#### Manually Enable in about:config
1. Navigate to `about:config`
2. Search for `sidebar.verticalTabs`
3. Toggle it to `true` if not already set
4. Restart Firefox

#### Check for Conflicting Extensions
Some extensions may interfere with vertical tabs:
- Tree Style Tab
- Sidebery
- Other tab management extensions

Try disabling these extensions temporarily to see if they're causing conflicts.

#### Reset Firefox Profile
If nothing else works, create a new profile:
```bash
firefox -ProfileManager
```

### Sidebar Not Showing

#### Toggle Sidebar Manually
1. Right-click on the tab bar
2. Select "Toggle Sidebar"
3. Or use `Ctrl+B`

#### Check Sidebar Position
Verify `sidebar.position_start` is set to your preferred side:
- `true` for left side
- `false` for right side

### Tabs Still Horizontal

#### Verify All Preferences
Ensure all required preferences are set:
```nix
"sidebar.revamp" = true;
"sidebar.verticalTabs" = true;
"sidebar.main.tools" = "verticaltabs";
```

#### Check Titlebar Setting
The `browser.tabs.inTitlebar` setting might affect tab display:
- `0` = Hide tabs from titlebar (recommended for vertical tabs)
- `1` = Show tabs in titlebar (default)

### Performance Issues

#### Reduce Sidebar Width
If vertical tabs feel slow, try reducing the width:
```nix
"sidebar.verticalTabs.width" = 150;
```

#### Disable Unused Sidebar Tools
Remove unused tools from the sidebar:
```nix
"sidebar.main.tools" = "verticaltabs";  # Only vertical tabs
```

## Customization

### Adjusting Tab Width

Control the minimum and clipping width of tabs:

```nix
{
  programs.firefox.profiles.default.settings = {
    "browser.tabs.tabMinWidth" = 76;      # Minimum tab width
    "browser.tabs.tabClipWidth" = 140;    # Width at which tab titles get clipped
  };
}
```

### Sidebar Position

Move vertical tabs to the right side:

```nix
{
  programs.firefox.profiles.default.settings = {
    "sidebar.position_start" = false;  # Right side instead of left
  };
}
```

### Multiple Sidebar Tools

Show multiple tools in the sidebar:

```nix
{
  programs.firefox.profiles.default.settings = {
    "sidebar.main.tools" = "verticaltabs,bookmarks,history";
  };
}
```

### Compact Mode

Enable compact mode for more screen space:

```nix
{
  programs.firefox.profiles.default.settings = {
    "browser.uidensity" = 0;  # 0 = compact, 1 = normal, 2 = touch
  };
}
```

### Custom CSS for Vertical Tabs

For advanced customization, you can use userChrome.css:

1. Enable userChrome.css:
```nix
{
  programs.firefox.profiles.default.settings = {
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
  };
}
```

2. Create `chrome/userChrome.css` in your Firefox profile with custom styles.

## Extension Compatibility

### Compatible Extensions

These extensions work well with vertical tabs:
- uBlock Origin
- Bitwarden
- Dark Reader
- Privacy Badger
- NoScript

### Potentially Conflicting Extensions

These extensions may conflict with vertical tabs:
- Tree Style Tab
- Sidebery
- Vertical Tabs Reloaded
- Tab Center Reborn

### Extension-Specific Settings

#### Bitwarden
The current configuration includes Bitwarden-specific settings:
```nix
"browser.nativeMessaging.bitwarden" = true;
"extensions.bitwarden@browser.duckduckgo.com.private" = true;
"extensions.bitwarden@browser.duckduckgo.com.toolbar" = true;
```

#### uBlock Origin
No special configuration needed, works out of the box with vertical tabs.

## Quick Reference

### Minimal Configuration
```nix
{
  programs.firefox.profiles.default.settings = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
  };
}
```

### Recommended Configuration
```nix
{
  programs.firefox.profiles.default.settings = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
    "sidebar.main.tools" = "verticaltabs";
    "sidebar.position_start" = true;
    "sidebar.verticalTabs.width" = 200;
    "browser.tabs.inTitlebar" = 0;
  };
}
```

### Keyboard Shortcuts
- `Ctrl+B`: Toggle sidebar
- `Ctrl+Shift+B`: Toggle bookmarks sidebar
- `Ctrl+H`: Open history sidebar

### Common about:config Preferences
```
sidebar.revamp = true
sidebar.verticalTabs = true
sidebar.main.tools = "verticaltabs"
sidebar.position_start = true
sidebar.verticalTabs.width = 200
browser.tabs.inTitlebar = 0
```

## Testing Your Configuration

Use the provided test script to validate your configuration:

```bash
# Make executable
chmod +x scripts/firefox-config-test.sh

# Run tests
./scripts/firefox-config-test.sh
```

The script will:
1. Check basic syntax evaluation
2. Test Home Manager integration
3. Validate no evaluation warnings
4. Confirm vertical tabs preferences are set

## Updating Your Configuration

When updating Firefox or NixOS:

1. Check if Firefox version has changed
2. Review release notes for any vertical tabs changes
3. Test your configuration after updates
4. Run the test script to verify everything works

## Getting Help

If you encounter issues:

1. Check the [Mozilla Firefox Support](https://support.mozilla.org/) site
2. Search the [NixOS Discourse](https://discourse.nixos.org/) forums
3. Review the [Home Manager documentation](https://nix-community.github.io/home-manager/)
4. Check the [Firefox issue tracker](https://bugzilla.mozilla.org/) for known issues

## References

- [Mozilla Firefox Release Notes](https://www.mozilla.org/en-US/firefox/releases/)
- [Home Manager Firefox Options](https://home-manager-options.extranix.com/?query=firefox)
- [Firefox about:config Documentation](https://support.mozilla.org/en-US/kb/about-config-editor-firefox)
- [NixOS Firefox Configuration](https://nixos.org/manual/nixos/stable/options.html#opt-programs.firefox)