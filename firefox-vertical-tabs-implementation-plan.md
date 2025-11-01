# Firefox Vertical Tabs Implementation Plan

## Problem Summary
The current Firefox configuration is using incorrect preference names for enabling vertical tabs in Firefox 136. The tabs are still appearing horizontally at the top despite the configuration.

## Root Cause Analysis
The current configuration in [`modules/firefox.nix`](modules/firefox.nix) contains these incorrect preferences:
```nix
"reader.toolbar.vertical" = true;
"firefox.tabs.show-newtab-vertical" = true;
"firefox.tabs.vertical" = true;
```

These preference names either don't exist or don't work for enabling vertical tabs in Firefox 136.

## Solution Implementation

### 1. Update Firefox Module Configuration

Replace the incorrect tab configuration in [`modules/firefox.nix`](modules/firefox.nix) (lines 38-41) with:

```nix
# Tab configuration - tabs on the left (Firefox 136 vertical tabs)
"sidebar.revamp" = true;                    # Enable sidebar revamp
"sidebar.verticalTabs" = true;              # Enable vertical tabs
"sidebar.main.tools" = "verticaltabs";      # Set vertical tabs as main sidebar tool
"sidebar.position_start" = true;            # Position sidebar on the left
```

### 2. Update Test Script

Modify [`scripts/firefox-config-test.sh`](scripts/firefox-config-test.sh) to include validation for the new vertical tabs preferences:

```bash
# Test 4: Check for correct vertical tabs preferences
echo "📋 Test 4: Validating vertical tabs configuration"
if nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; lib = pkgs.lib; cfg = { programs.firefox.enable = true; programs.firefox.preferences = {}; }; in (import ./modules/firefox.nix { config = cfg; inherit lib pkgs; }).config.programs.firefox.profiles.default.settings' 2>&1 | grep -q "sidebar.revamp"; then
    echo "✅ sidebar.revamp preference found"
else
    echo "❌ sidebar.revamp preference missing"
    exit 1
fi

if nix-instantiate --eval --expr 'let pkgs = import <nixpkgs> {}; lib = pkgs.lib; cfg = { programs.firefox.enable = true; programs.firefox.preferences = {}; }; in (import ./modules/firefox.nix { config = cfg; inherit lib pkgs; }).config.programs.firefox.profiles.default.settings' 2>&1 | grep -q "sidebar.verticalTabs"; then
    echo "✅ sidebar.verticalTabs preference found"
else
    echo "❌ sidebar.verticalTabs preference missing"
    exit 1
fi
```

### 3. Verification Steps

After applying the configuration changes:

1. **Rebuild the configuration**:
   ```bash
   home-manager switch
   ```

2. **Restart Firefox** completely (close all instances)

3. **Verify vertical tabs are enabled**:
   - Right-click on the tab bar area
   - Select "Toggle Sidebar" → "Vertical Tabs"
   - Or use Ctrl+B to toggle the sidebar

4. **Manual verification in about:config**:
   - Visit `about:config`
   - Search for `sidebar.verticalTabs` - should be `true`
   - Search for `sidebar.revamp` - should be `true`

## Implementation Order

1. Update [`modules/firefox.nix`](modules/firefox.nix) with correct preferences
2. Update test script to validate new preferences
3. Test the configuration
4. Update documentation (already completed in [`docs/firefox-configuration-guide.md`](docs/firefox-configuration-guide.md))

## Expected Outcome

After implementing these changes:
- Firefox tabs will appear vertically in the left sidebar
- The vertical tabs feature will be properly enabled through the correct Firefox 136 preferences
- The configuration will be persistent across Firefox restarts
- The test script will validate that the correct preferences are set

## Files to Modify

1. [`modules/firefox.nix`](modules/firefox.nix) - Update vertical tabs preferences
2. [`scripts/firefox-config-test.sh`](scripts/firefox-config-test.sh) - Add validation tests

## Testing Strategy

1. Run the updated test script to verify configuration syntax
2. Apply the configuration with `home-manager switch`
3. Restart Firefox and verify vertical tabs appear
4. Check `about:config` to confirm preferences are set correctly

## Additional Troubleshooting (If Initial Fix Doesn't Work)

### 1. Verify Firefox Version
Check if you're actually running Firefox 136+:
```bash
firefox --version
```

If not running Firefox 136+, the vertical tabs feature may not be available.

### 2. Additional Preferences That May Be Needed
Some users report needing these additional preferences:

```nix
# Additional preferences that might be required
"browser.tabs.inTitlebar" = 0;               # Move tabs out of titlebar
"browser.uidensity" = 0;                     # Compact mode (may help)
"sidebar.verticalTabs.width" = 200;          # Set explicit width
"browser.tabs.tabmanager.enabled" = false;  # Disable tab manager
```

### 3. Alternative Configuration Approach
If the above doesn't work, try this alternative configuration:

```nix
# Alternative vertical tabs configuration
"sidebar.revamp" = true;
"sidebar.verticalTabs" = true;
"sidebar.main.tools" = "verticaltabs,bookmarks,history";
"browser.tabs.tabMinWidth" = 76;
"browser.tabs.tabClipWidth" = 140;
```

### 4. Manual Activation Steps
If preferences alone don't work:

1. Open Firefox
2. Right-click on the tab bar
3. Select "Toggle Sidebar" → "Vertical Tabs"
4. Or use keyboard shortcut: `Ctrl+B` to toggle sidebar
5. Click the sidebar panel icon (if visible) and select "Vertical Tabs"

### 5. Check for Conflicting Extensions
Some extensions may interfere with vertical tabs:
- Try disabling all extensions temporarily
- Specifically check for tab-related extensions

### 6. Firefox Profile Issues
Create a new Firefox profile to test:
```bash
firefox -ProfileManager
```

### 7. System-Level Configuration
If user-level configuration doesn't work, try adding to system policies in [`modules/firefox-system.nix`](modules/firefox-system.nix):

```nix
policies = {
  # Add to existing policies
  Preferences = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
    "sidebar.main.tools" = "verticaltabs";
  };
};
```

### 8. NixOS-Specific Considerations
On NixOS, Firefox may need to be wrapped with additional flags:

```nix
programs.firefox.package = pkgs.firefox.override {
  extraPolicies = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
  };
};
```

## Debugging Steps

1. **Check about:config**:
   - Visit `about:config`
   - Search for all `sidebar` preferences
   - Verify they match your configuration
   - Try toggling them manually

2. **Check Browser Console**:
   - Open Developer Tools (F12)
   - Check Console tab for any errors related to sidebar

3. **Test with Fresh Profile**:
   - Create new profile
   - Apply same preferences
   - See if issue persists

4. **Verify Configuration Application**:
   - Check Home Manager logs: `home-manager switch`
   - Look for any Firefox-related warnings