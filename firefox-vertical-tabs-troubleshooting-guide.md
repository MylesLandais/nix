# Firefox Vertical Tabs Troubleshooting Guide

## Issue: Vertical Tabs Not Appearing After Configuration Update

### Quick Diagnosis Checklist

1. **Firefox Version Check**
   ```bash
   firefox --version
   ```
   - Must be Firefox 136 or later for built-in vertical tabs
   - If using older version, vertical tabs may not be available

2. **Verify Preferences Applied**
   - Visit `about:config` in Firefox
   - Search for `sidebar.revamp` and `sidebar.verticalTabs`
   - Both should be set to `true`
   - If not present, configuration wasn't applied correctly

3. **Manual Activation**
   - Right-click on tab bar area
   - Look for "Toggle Sidebar" → "Vertical Tabs" option
   - Try keyboard shortcut: `Ctrl+B`

## Step-by-Step Troubleshooting

### Step 1: Confirm Configuration Application

First, verify that your NixOS/Home Manager configuration was applied:

```bash
# Check Home Manager output for any warnings
home-manager switch

# Look specifically for Firefox-related messages
home-manager switch 2>&1 | grep -i firefox
```

### Step 2: Check Firefox Profile Location

Firefox stores preferences in your profile directory. Verify the correct profile is being used:

1. Visit `about:profiles` in Firefox
2. Check which profile is "in use"
3. Verify the profile path matches your Home Manager configuration

### Step 3: Manual Preference Verification

If preferences aren't showing in `about:config`:

1. **Try setting manually first**:
   - Visit `about:config`
   - Create/modify these preferences:
     - `sidebar.revamp` = `true`
     - `sidebar.verticalTabs` = `true`
     - `sidebar.main.tools` = `"verticaltabs"`
   - Restart Firefox
   - Check if vertical tabs appear

2. **If manual setting works**, the issue is with configuration application
3. **If manual setting doesn't work**, the issue may be with Firefox version or compatibility

### Step 4: Alternative Configuration Approaches

#### Option A: Extended Preference Set
Try this expanded configuration in [`modules/firefox.nix`](modules/firefox.nix):

```nix
# Comprehensive vertical tabs configuration
"sidebar.revamp" = true;
"sidebar.verticalTabs" = true;
"sidebar.main.tools" = "verticaltabs";
"sidebar.position_start" = true;
"sidebar.verticalTabs.width" = 200;
"browser.tabs.inTitlebar" = 0;
"browser.uidensity" = 0;
"browser.tabs.tabMinWidth" = 76;
"browser.tabs.tabClipWidth" = 140;
```

#### Option B: System-Level Policies
Add to [`modules/firefox-system.nix`](modules/firefox-system.nix):

```nix
policies = cfg.policies // {
  # Add to existing policies
  Preferences = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
    "sidebar.main.tools" = "verticaltabs";
    "sidebar.position_start" = true;
  };
};
```

#### Option C: Firefox Package Override
In your `home.nix` or appropriate configuration:

```nix
programs.firefox.package = pkgs.firefox.override {
  extraPolicies = {
    "sidebar.revamp" = true;
    "sidebar.verticalTabs" = true;
    "sidebar.main.tools" = "verticaltabs";
  };
};
```

### Step 5: Extension Conflicts

Temporarily disable all extensions to test for conflicts:

1. Visit `about:addons`
2. Disable all extensions
3. Restart Firefox
4. Test vertical tabs
5. Re-enable extensions one by one to identify conflicts

### Step 6: Profile Reset Test

Create a fresh profile to isolate the issue:

```bash
# Backup current profile
cp -r ~/.mozilla/firefox ~/.mozilla/firefox.backup

# Create new profile
firefox -ProfileManager

# Test with new profile
```

### Step 7: NixOS-Specific Debugging

#### Check Firefox Wrapper
NixOS may wrap Firefox with additional settings:

```bash
# Check how Firefox is launched
which firefox
readlink -f $(which firefox)

# Check Firefox package details
nix eval nixpkgs.firefox
```

#### Verify Home Manager Integration
```bash
# Test Home Manager Firefox configuration
nix-instantiate --eval --expr '
  let 
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    cfg = { programs.firefox.enable = true; };
  in 
  (import ./modules/firefox.nix { config = cfg; inherit lib pkgs; })
'
```

## Common Issues and Solutions

### Issue 1: Preferences Not Applied
**Symptoms**: Preferences don't appear in `about:config`
**Solution**: 
- Verify Home Manager configuration syntax
- Check for conflicting Firefox configurations
- Try system-level policies instead

### Issue 2: Vertical Tabs Option Not Available
**Symptoms**: No "Vertical Tabs" option in sidebar menu
**Solution**:
- Verify Firefox version (136+)
- Check if feature is enabled in your Firefox build
- Try manual preference setting

### Issue 3: Tabs Appear But Disappear
**Symptoms**: Vertical tabs appear briefly then revert to horizontal
**Solution**:
- Check for extension conflicts
- Verify all required preferences are set
- Try extended preference set

### Issue 4: Sidebar Shows But No Tabs
**Symptoms**: Sidebar appears but empty or shows other content
**Solution**:
- Verify `sidebar.main.tools` includes "verticaltabs"
- Check `sidebar.position_start` setting
- Try manual sidebar tool selection

## Advanced Troubleshooting

### Firefox Build Information
Check if your Firefox build includes vertical tabs:

```bash
# Check Firefox build details
firefox --version

# Check about:buildconfig for feature flags
# Visit about:buildconfig in Firefox
```

### NixOS Channel Updates
Ensure you're using updated NixOS channels:

```bash
# Check channel
nix-channel --list

# Update channels
nix-channel --update

# Rebuild with updated packages
sudo nixos-rebuild switch
```

### Alternative Vertical Tabs Solutions

If built-in vertical tabs don't work:

1. **Tree Style Tab Extension**:
   ```nix
   extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
     # ... other extensions
     tree-style-tab
   ];
   ```

2. **Sidebery Extension**:
   ```nix
   extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
     # ... other extensions
     sidebery
   ];
   ```

## Next Steps

If none of these solutions work:

1. **Check Firefox release notes** for your version
2. **Report bug** to NixOS or Home Manager if configuration isn't being applied
3. **Consider using extension-based vertical tabs** as alternative
4. **Test with different Firefox package** (e.g., firefox-beta, firefox-esr)

## Testing Script

Create a test script to verify all aspects:

```bash
#!/usr/bin/env bash
echo "🔍 Firefox Vertical Tabs Diagnostic"
echo "=================================="

echo "📋 Firefox Version:"
firefox --version

echo ""
echo "📋 Checking Home Manager Configuration:"
if home-manager switch 2>&1 | grep -q "error"; then
    echo "❌ Configuration errors found"
else
    echo "✅ Configuration applied successfully"
fi

echo ""
echo "📋 Manual Verification Steps:"
echo "1. Visit about:config"
echo "2. Search for 'sidebar.revamp' and 'sidebar.verticalTabs'"
echo "3. Both should be set to true"
echo "4. Try Ctrl+B to toggle sidebar"
echo "5. Right-click tab bar for sidebar options"