#!/usr/bin/env bash

# ==============================================================================
#
#          System Information Report Generator
#
# Description: This script gathers detailed information about system hardware,
#              drivers, and video encoding capabilities, saving it to a
#              text file for analysis.
#
# Usage:       ./generate_report.sh
#              The script may require sudo privileges for some commands (lshw)
#              and will prompt for a password if necessary.
#
# ==============================================================================

# --- Configuration ---
OUTPUT_FILE="system_info_report.txt"

# --- Helper Functions ---

# Function to start the report and clear any previous content
start_report() {
    echo "=========================================" > "$OUTPUT_FILE"
    echo "      System Information Report" >> "$OUTPUT_FILE"
    echo "  Generated on: $(date)" >> "$OUTPUT_FILE"
    echo "=========================================" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
}

# Function to add a section header and command output to the report
add_to_report() {
    local title="$1"
    local command_to_run="$2"

    echo "### $title ###" >> "$OUTPUT_FILE"
    echo "--------------------------------------------------" >> "$OUTPUT_FILE"
    # Check if command exists before trying to run it
    if ! command -v "${command_to_run%% *}" &> /dev/null; then
        echo "Command not found: ${command_to_run%% *}" >> "$OUTPUT_FILE"
    else
        echo "Running: $command_to_run" >> "$OUTPUT_FILE"
        # Run the command and append both stdout and stderr to the report
        eval "$command_to_run" >> "$OUTPUT_FILE" 2>&1
    fi
    echo "--------------------------------------------------" >> "$OUTPUT_FILE"
    echo -e "\n" >> "$OUTPUT_FILE"
}

# --- Main Script Execution ---

# Notify user that the script is starting
echo "Generating system information report..."
echo "Some commands may require sudo privileges."

# 1. Initialize the report file
start_report

# 2. Gather General System Information
add_to_report "Operating System Details" "cat /etc/os-release"
add_to_report "Kernel Version" "uname -a"
add_to_report "CPU Information" "lscpu"
add_to_report "Memory Usage" "free -h"

# 3. Gather GPU and Hardware Information
add_to_report "PCI Devices (Filtered for GPU)" "lspci | grep -i -E 'vga|3d|display'"
add_to_report "PCI Devices with Kernel Modules (Filtered for GPU)" "lspci -k | grep -i -A3 'vga|3d'"
add_to_report "Detailed Display Hardware Info" "sudo lshw -C display"

# 4. Gather Display, Driver, and Encoding Information
add_to_report "OpenGL / Renderer Information" "glxinfo -B"
add_to_report "VA-API Information (Intel/AMD)" "vainfo"
add_to_report "NVIDIA System Management Interface (NVIDIA)" "nvidia-smi"

# 5. Gather Software and Library Information
add_to_report "Loaded Kernel Modules (Filtered for GPU)" "lsmod | grep -E 'nvidia|amdgpu|i915|radeon'"
add_to_report "Linked Video/Encoding Libraries" "ldconfig -p | grep -i -E 'nvenc|nvencc|va|vdpau|v4l2'"

# 6. Gather Kernel Log Information
add_to_report "Kernel Messages (DRM)" "dmesg | grep -i drm"
add_to_report "Kernel Messages (NVIDIA)" "dmesg | grep -i nvidia"

# --- Finalization ---
echo "Report generation complete."
echo "Output saved to: $OUTPUT_FILE"

exit 0
