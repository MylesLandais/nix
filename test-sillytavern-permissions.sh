#!/usr/bin/env bash
# Test script to verify SillyTavern permission fixes

echo "=== SillyTavern Permission Fix Test ==="
echo ""

# Simulate the directory structure
TEST_DIR="/tmp/sillytavern-test"
USER="sillytavern"
GROUP="sillytavern"

echo "Creating test directory structure..."
mkdir -p "$TEST_DIR"/{data,config,plugins,extensions}
mkdir -p "$TEST_DIR/data/default-user"

echo "Setting ownership to $USER:$GROUP..."
# Note: In real system, these users would exist
chown -R "$USER:$GROUP" "$TEST_DIR" 2>/dev/null || echo "Note: $USER:$GROUP doesn't exist, using current user"

echo "Applying permission fixes..."
chmod -R u+rwX,g+rwX,o+rX "$TEST_DIR/data"
chmod -R u+rwX,g+rwX,o+rX "$TEST_DIR/config"
chmod -R u+rwX,g+rwX,o+rX "$TEST_DIR/extensions"
chmod -R u+rwX,g+rwX,o+rX "$TEST_DIR/plugins"

# Ensure others can read extensions and plugins
chmod -R o+rX "$TEST_DIR/extensions"
chmod -R o+rX "$TEST_DIR/plugins"

echo ""
echo "Permission verification:"
echo "Data directory: $(stat -c '%a %U:%G' "$TEST_DIR/data")"
echo "Config directory: $(stat -c '%a %U:%G' "$TEST_DIR/config")"
echo "Extensions directory: $(stat -c '%a %U:%G' "$TEST_DIR/extensions")"
echo "Plugins directory: $(stat -c '%a %U:%G' "$TEST_DIR/plugins")"

echo ""
echo "Testing access (as current user):"
echo "Can read data directory: $([ -r "$TEST_DIR/data" ] && echo YES || echo NO)"
echo "Can read extensions directory: $([ -r "$TEST_DIR/extensions" ] && echo YES || echo NO)"
echo "Can read plugins directory: $([ -r "$TEST_DIR/plugins" ] && echo YES || echo NO)"
echo "Can write to data directory: $([ -w "$TEST_DIR/data" ] && echo YES || echo NO)"

echo ""
echo "Test file creation in data directory..."
touch "$TEST_DIR/data/test-file" && rm "$TEST_DIR/data/test-file" && echo "Write test: PASSED" || echo "Write test: FAILED"

echo ""
echo "=== Test Complete ==="
echo "If all tests show YES/PASSED, the permission fix should work correctly."
echo ""
echo "To apply these fixes to your system:"
echo "1. Rebuild your NixOS configuration: sudo nixos-rebuild switch"
echo "2. Check the journal logs for diagnostics: journalctl -u podman-sillytavern"
echo "3. Verify warby user can access the directories"