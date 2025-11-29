#!/usr/bin/env bash
# Manual verification script for SillyTavern permissions

echo "=== SillyTavern Permissions Verification ==="
echo ""

DATA_DIR="/var/lib/sillytavern"

echo "1. Checking directory ownership and permissions:"
echo "Data directory: $(stat -c '%a %U:%G' "$DATA_DIR/data" 2>/dev/null || echo "Directory not found")"
echo "Config directory: $(stat -c '%a %U:%G' "$DATA_DIR/config" 2>/dev/null || echo "Directory not found")"
echo "Extensions directory: $(stat -c '%a %U:%G' "$DATA_DIR/extensions" 2>/dev/null || echo "Directory not found")"
echo "Plugins directory: $(stat -c '%a %U:%G' "$DATA_DIR/plugins" 2>/dev/null || echo "Directory not found")"
echo ""

echo "2. Checking user group membership:"
echo "Warby user groups: $(groups warby 2>/dev/null || echo "warby user not found")"
echo "Sillytavern group members: $(getent group sillytavern 2>/dev/null || echo "sillytavern group not found")"
echo ""

echo "3. Testing warby user access:"
if [ -d "$DATA_DIR/extensions" ]; then
    if [ -r "$DATA_DIR/extensions" ]; then
        echo "✓ Warby can READ extensions directory"
    else
        echo "✗ Warby cannot READ extensions directory"
    fi
else
    echo "✗ Extensions directory not found"
fi

if [ -d "$DATA_DIR/plugins" ]; then
    if [ -r "$DATA_DIR/plugins" ]; then
        echo "✓ Warby can READ plugins directory"
    else
        echo "✗ Warby cannot READ plugins directory"
    fi
else
    echo "✗ Plugins directory not found"
fi

if [ -d "$DATA_DIR/data" ]; then
    if [ -w "$DATA_DIR/data" ]; then
        echo "✓ Warby can WRITE to data directory"
    else
        echo "✗ Warby cannot WRITE to data directory"
    fi
else
    echo "✗ Data directory not found"
fi

echo ""

echo "4. Testing file creation in data directory:"
TEST_FILE="$DATA_DIR/data/permission-test-$(date +%s)"
if touch "$TEST_FILE" 2>/dev/null; then
    rm "$TEST_FILE"
    echo "✓ Warby can create files in data directory"
else
    echo "✗ Warby cannot create files in data directory"
fi

echo ""

echo "5. Checking SillyTavern service status:"
if systemctl is-active --quiet podman-sillytavern; then
    echo "✓ SillyTavern service is running"
    echo "  Container URL: http://127.0.0.1:8765"
else
    echo "✗ SillyTavern service is not running"
    echo "  Try: sudo systemctl start podman-sillytavern"
fi

echo ""
echo "=== Verification Complete ==="