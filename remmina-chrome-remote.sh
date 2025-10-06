#!/usr/bin/env bash
# Script to create a Remmina profile for Chrome Remote VNC with SSH tunneling
# This creates a secure connection to the chrome-remote container

set -e

# Configuration
REMOTE_HOST="localhost"  # Change this if connecting remotely
SSH_USER="warby"        # Change this to your SSH username
VNC_LOCAL_PORT="5901"
VNC_REMOTE_PORT="5900"
PROFILE_NAME="Chrome-Remote-Secure"

# Create Remmina profile directory if it doesn't exist
PROFILE_DIR="$HOME/.config/remmina"
mkdir -p "$PROFILE_DIR"

# Generate a unique profile name
PROFILE_FILE="$PROFILE_DIR/${PROFILE_NAME}.remmina"

# Create Remmina profile with SSH tunneling
cat > "$PROFILE_FILE" << EOF
[remmina]
name=$PROFILE_NAME
tags=
protocol=VNC
server=localhost:$VNC_LOCAL_PORT
username=
password=
ssh_server=$REMOTE_HOST
ssh_username=$SSH_USER
ssh_privatekey=
ssh_charset=UTF-8
ssh_read_fps=1
ssh_server_alive_interval=0
ssh_server_alive_count_max=3
set_primary_password=0
clientname=
quality=9
jpeg_quality=9
png_quality=9
viewmode=1
viewonly=0
toolbar_visibility=1
showcursor=1
ssh_tunnel_enabled=1
ssh_tunnel_loopback=1
enableaudio=0
audio_channels=2
audio_quality=0
ssh_tunnel_port=$VNC_REMOTE_PORT
loadbalance=0
loadbalance_info=
enableautostart=0
ssh_tunnel_password=
ssh_tunnel_privatekey=
EOF

echo "Created Remmina profile: $PROFILE_FILE"
echo ""
echo "To use this secure connection:"
echo "1. Open Remmina"
echo "2. Load the '$PROFILE_NAME' profile"
echo "3. Enter your SSH password when prompted"
echo "4. The VNC connection will be tunneled securely through SSH"
echo ""
echo "Remmina SSH Tunneling Setup:"
echo "- Protocol: VNC"
echo "- Server: localhost:$VNC_LOCAL_PORT"
echo "- SSH Tunnel: Enabled"
echo "- SSH Server: $REMOTE_HOST"
echo "- SSH Username: $SSH_USER"
echo "- SSH Tunnel Port: $VNC_REMOTE_PORT"
echo ""
echo "Manual SSH tunnel command:"
echo "ssh -L $VNC_LOCAL_PORT:localhost:$VNC_REMOTE_PORT $SSH_USER@$REMOTE_HOST"
echo "Then connect any VNC client to localhost:$VNC_LOCAL_PORT with password 'devsandbox123'"