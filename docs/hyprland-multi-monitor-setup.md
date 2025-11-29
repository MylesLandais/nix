# Hyprland Multi-Monitor Setup Guide

This guide covers the implementation and validation of a 4-monitor setup in Hyprland with the following configuration:

## Monitor Layout

```
[ Top: Samsung 1920x1080 (ws10) ]
     Position: x=8140, y=1080 (centered above middle)

[ Bottom Row: Three Dell monitors ]
Left (Tertiary):   x=5900, y=2160   (ws3/6/9)
Middle (Main):     x=7820, y=2160   (ws2/5/8) 
Right (Secondary): x=10380, y=2160  (ws1/4/7)
```

## Workspace Distribution

- **Samsung (Top)**: Workspace 10 (explicitly assigned)
- **Bottom Dells**: Workspaces 1-9 (dynamically assigned - will stick to the monitor where first opened)

This simplified approach ensures better compatibility with hyprpanel while still providing organization.

## Implementation Steps

### 1. Configuration Changes

The following files have been modified:
- `hypr.nix`: Updated monitor positions, workspace assignments, and keybinds
- `hyprpanel.nix`: Updated to support 10 workspaces

### 2. Validation and Testing

#### Step 1: Dry-run Check
```bash
sudo nixos-rebuild dry-run
```
This checks for syntax errors without applying changes.

#### Step 2: Apply Configuration
```bash
sudo nixos-rebuild switch
```

#### Step 3: Restart Hyprland
Either log out and log back in, or run:
```bash
hyprctl dispatch exit
```

#### Step 4: Run Validation Script
```bash
./scripts/validate-hyprland-monitors.sh
```

#### Step 5: Manual Testing
Test the following keybinds:
- `Super+1` through `Super+0`: Switch to workspaces 1-10
- `Super+Shift+1` through `Super+Shift+0`: Move focused window to workspaces 1-10
- `Super+H/L/K/J`: Move focus left/right/up/down
- `Super+mouse_wheel`: Cycle through workspaces

#### Step 6: Organize Workspaces (Optional)
To organize workspaces 1-9 across your three bottom monitors:
1. Open an application on workspace 1 on the right Dell
2. Open an application on workspace 2 on the middle Dell
3. Open an application on workspace 3 on the left Dell
4. Continue this pattern (4,7 on right; 5,8 on middle; 6,9 on left)
5. Workspaces will "stick" to the monitor where they're first used

#### Step 6: Monitor Verification
Check monitor positions with:
```bash
hyprctl monitors
```

Verify workspace assignments with:
```bash
hyprctl workspaces
```

### 3. Troubleshooting

#### Common Issues and Solutions

1. **Monitor not detected**
   - Check physical connections
   - Verify cable integrity
   - Check GPU driver status

2. **Wrong monitor position**
   - Verify the `desc:` identifiers match your actual monitors
   - Check the x,y coordinates in the configuration

3. **Workspace not sticking to monitor**
   - For workspace 10: Check if Samsung monitor is connected
   - For workspaces 1-9: Open an application on the desired monitor first
   - Workspaces 1-9 are dynamic and stick to where first used

4. **Black screen on Samsung monitor**
   - Verify refresh rate (29.97Hz for Samsung)
   - Check if the monitor supports the configured resolution

5. **Keybinds not working**
   - Ensure keybinds are extended to 10 workspaces
   - Check for conflicting keybinds

#### Recovery Commands

If something goes wrong, you can always rollback:
```bash
sudo nixos-rebuild switch --rollback
```

### 4. Git Commit Process

#### Option 1: Direct Commit (Quick)
```bash
git add hypr.nix scripts/validate-hyprland-monitors.sh docs/hyprland-multi-monitor-setup.md
git commit -m "Update Hyprland monitors and workspaces for multi-monitor setup with Samsung stacked"
git push origin main
```

#### Option 2: Feature Branch (Safer)
```bash
# Create and switch to feature branch
git checkout -b feature/hyprland-multi-monitor

# Add changes
git add hypr.nix scripts/validate-hyprland-monitors.sh docs/hyprland-multi-monitor-setup.md

# Commit with detailed message
git commit -m "feat: Implement 4-monitor Hyprland configuration

- Add Samsung monitor positioned above middle Dell at x=8140,y=1080
- Configure workspace assignments: Samsung(ws10), Right Dell(1,4,7), Middle Dell(2,5,8), Left Dell(3,6,9)
- Extend keybinds to support workspace 10 (Super+0, Super+Shift+0)
- Add validation script for testing monitor configuration
- Add comprehensive documentation for the setup"

# Push to remote
git push origin feature/hyprland-multi-monitor

# Merge to main when ready
git checkout main
git merge feature/hyprland-multi-monitor
git push origin main
```

### 5. Maintenance

#### Adding New Monitors
1. Update `vars.nix` with new monitor details
2. Add monitor to `monitor` list in `hypr.nix`
3. Assign workspaces in `workspace` list
4. Update keybinds if needed
5. Update hyprpaper configuration
6. Update `workspaces.amount` in `hyprpanel.nix` to match total workspace count

#### Changing Workspace Distribution
1. Modify the `workspace` list in `hypr.nix`
2. Update `workspaces.amount` in `hyprpanel.nix` to match total workspace count
3. Test with validation script
4. Update documentation if needed

#### Panel Issues
If the panel doesn't show all workspaces correctly:
1. Ensure `workspaces.amount` in `hyprpanel.nix` matches your total workspace count
2. Restart hyprpanel: `pkill hyprpanel && hyprpanel &`
3. Check hyprpanel logs for errors

## Technical Details

### Monitor Descriptors
The configuration uses `desc:` identifiers which are more reliable than port names:
- Samsung: `desc:Samsung Electric Company SAMSUNG 0x01000E00`
- Main Dell: `desc:Dell Inc. Dell S2716DG ##ASPYT+r5vCzd`
- Secondary Dell: `desc:Dell Inc. DELL P2422H 46Z5YB3`
- Tertiary Dell: `desc:Dell Inc. DELL P2422H 62K3NK3`

### Position Calculations
- Bottom row aligned at y=2160
- Samsung positioned at y=1080 (touches bottom row)
- Horizontal spacing ensures no gaps between monitors
- Samsung centered above middle Dell (x=8140)

### Keybind Extensions
The keybind generation was extended from 9 to 10 workspaces:
```nix
builtins.genList (...) 10  # Extended from 9 to 10 workspaces
```

This adds support for Super+0 and Super+Shift+0 keybinds.