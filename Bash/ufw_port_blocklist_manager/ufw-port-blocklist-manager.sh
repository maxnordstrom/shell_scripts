#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# === Port Blocklist Script for UFW ===
#
# This script applies or removes a port blocklist using UFW firewall. 
# The script needs a list of port numbers as input. Save the list of ports
# as port_blocklist.txt. 
#
# 
#
#
#

# Check if required tools are installed
if ! command -v ufw &> /dev/null; then
    echo "ERROR: UFW is not installed."
    echo "Install with: sudo apt install ufw"
    exit 1
fi

# Path to blocklist file
BLOCKLIST_FILE="./port_blocklist.txt"

# Check if blocklist file exists
if [ ! -f "$BLOCKLIST_FILE" ]; then
    echo "ERROR: Blocklist file not found: $BLOCKLIST_FILE"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Read blocklist from file into array
mapfile -t BLOCKLIST < "$BLOCKLIST_FILE"

# Create reports directory if it doesn't exist
REPORT_DIR="./reports"
if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR"
fi

# Tag used to identify blocklist rules
BLOCKLIST_TAG="PORT_BLOCKLIST_RULE"

# Function to apply the blocklist
apply_blocklist() {
    echo "" # Adding newline

    # Enable UFW if not already enabled
    ufw --force enable
    
    echo "Applying port blocklist..."
    
    # Variables for the report
    REPORT_FILE="$REPORT_DIR/port_blocklist_report_$(date +%Y%m%d_%H%M%S).txt"
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Start creating the report
    echo "===== PORT BLOCKLIST APPLIED =====" > "$REPORT_FILE"
    echo "Date and Time: $CURRENT_TIME" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Ports added to blocklist:" >> "$REPORT_FILE"
    
    # Loop through each port in the blocklist
    for port in "${BLOCKLIST[@]}"; do
        # Skip empty lines
        if [ -z "$port" ]; then
            continue
        fi
        
        echo "  Blocking port: $port"
        
        # Block incoming traffic on this port with comment tag
        ufw deny in "$port" comment "$BLOCKLIST_TAG" > /dev/null 2>&1
        
        # Block outgoing traffic on this port with comment tag
        ufw deny out "$port" comment "$BLOCKLIST_TAG" > /dev/null 2>&1
        
        # Add to report
        echo "  - Port $port (in- and outbound)" >> "$REPORT_FILE"
    done
    
    # Reload UFW to apply changes
    ufw reload
    
    echo ""
    echo "✓ PORT BLOCKLIST APPLIED SUCCESSFULLY"
    echo "Report saved to: $REPORT_FILE"
}

# Function to remove only blocklist rules
remove_blocklist_rules_only() {
    # Get all rule numbers with the blocklist tag (in reverse order)
    rule_numbers=$(ufw status numbered | grep "$BLOCKLIST_TAG" | awk -F'[][]' '{print $2}' | sort -rn)
    
    # Delete each rule by number
    for rule_num in $rule_numbers; do
        ufw --force delete "$rule_num" > /dev/null 2>&1
    done
}

# Function to remove the blocklist
remove_blocklist() {
    echo ""
    echo "Removing port blocklist..."
    
    # Remove blocklist rules
    remove_blocklist_rules_only
    
    # Reload UFW to apply changes
    ufw reload
    
    # Create warning report
    REPORT_FILE="$REPORT_DIR/port_blocklist_removed_$(date +%Y%m%d_%H%M%S).txt"
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "===== WARNING! =====" > "$REPORT_FILE"
    echo "Date and Time: $CURRENT_TIME" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Warning! The port blocklist has been removed, all ports are now unblocked." >> "$REPORT_FILE"
    
    echo ""
    echo "✓ PORT BLOCKLIST REMOVED SUCCESSFULLY"
    echo "Report saved to: $REPORT_FILE"
}

# Main script starts here
echo "=================================="
echo "  Port Blocklist Manager"
echo "=================================="
echo ""
echo "Choose an option:"
echo "1) APPLY port blocklist"
echo "2) REMOVE port blocklist"
echo ""
read -r -p "Enter your choice (1 or 2): " choice

# Process user choice
if [ "$choice" = "1" ]; then
    apply_blocklist
elif [ "$choice" = "2" ]; then
    remove_blocklist
else
    echo "ERROR: Invalid choice. Please run the script again and choose 1 or 2."
    exit 1
fi

echo ""
echo "Done!"