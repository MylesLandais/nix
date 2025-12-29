#!/usr/bin/env bash
# Monitor Hyprland for DPMS events and auto-reload config
# This helps fix workspace/bar issues when monitors power cycle

set -e

echo "Starting Hyprland DPMS monitor..."

# Get the Hyprland instance signature
HYPRLAND_INSTANCE="${HYPRLAND_INSTANCE_SIGNATURE}"

if [ -z "$HYPRLAND_INSTANCE" ]; then
    echo "Error: HYPRLAND_INSTANCE_SIGNATURE not set. Is Hyprland running?"
    exit 1
fi

# Hyprland socket path
SOCKET="/tmp/hypr/${HYPRLAND_INSTANCE}/.socket2.sock"

if [ ! -S "$SOCKET" ]; then
    echo "Error: Hyprland socket not found at $SOCKET"
    exit 1
fi

echo "Monitoring socket: $SOCKET"
echo "Press Ctrl+C to stop"
echo ""

# Variables to track monitor state
MONITOR_COUNT=$(hyprctl monitors | grep "^Monitor" | wc -l)
echo "Initial monitor count: $MONITOR_COUNT"

# Monitor events
{
    while read -r line; do
        # Check for monitor events
        if echo "$line" | grep -q "monitoradded\|monitorremoved"; then
            echo "$(date '+%H:%M:%S') - Monitor change detected: $line"

            # Wait a bit for Hyprland to stabilize
            sleep 1

            # Get new monitor count
            NEW_COUNT=$(hyprctl monitors | grep "^Monitor" | wc -l)
            echo "$(date '+%H:%M:%S') - Monitor count: $MONITOR_COUNT -> $NEW_COUNT"

            # Reload Hyprland config
            echo "$(date '+%H:%M:%S') - Reloading Hyprland config..."
            hyprctl reload

            # Restart hyprpanel
            echo "$(date '+%H:%M:%S') - Restarting hyprpanel..."
            hyprpanel restart

            MONITOR_COUNT=$NEW_COUNT
            echo "$(date '+%H:%M:%S') - Reload complete"
            echo ""
        fi

        # Also check for workspace events (optional)
        if echo "$line" | grep -q "workspacev2"; then
            # Just to show we're receiving events
            :
        fi
    done < <(socat - "UNIX-CONNECT:$SOCKET" 2>/dev/null)
} || {
    echo "Error: Failed to monitor socket. Make sure socat is installed."
    exit 1
}
