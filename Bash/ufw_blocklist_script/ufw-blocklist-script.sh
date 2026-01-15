#!/bin/bash

# Website Blocklist Script for UFW
# This script applies or removes a website blocklist using UFW firewall
#

# Check if required tools are installed
if ! command -v ufw &> /dev/null; then
    echo "ERROR: UFW is not installed."
    echo "Install with: sudo apt install ufw"
    exit 1
fi

if ! command -v dig &> /dev/null; then
    echo "ERROR: dig is not installed."
    echo "Install with: sudo apt install dnsutils"
    exit 1
fi

# Path to blocklist file
BLOCKLIST_FILE="./blocklist.txt"

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
BLOCKLIST_TAG="BLOCKLIST_RULE"

# Function to apply the blocklist
apply_blocklist() {
    # Just a newline to make it look nice
    echo ""

    # Enable UFW if not already enabled
    ufw --force enable
    
    echo "Applying blocklist..."
    
    # Set default policy to allow outgoing traffic
    ufw default allow outgoing > /dev/null 2>&1
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow routed > /dev/null 2>&1
    
    # Block HTTP (port 80) globally with comment tag
    ufw deny out 80 comment "$BLOCKLIST_TAG" > /dev/null 2>&1
    
    # Allow HTTPS (port 443) globally - this is already allowed by default policy
    # but we can be explicit about it
    ufw allow out 443 comment "$BLOCKLIST_TAG" > /dev/null 2>&1
    
    # Variables for the report
    REPORT_FILE="$REPORT_DIR/blocklist_report_$(date +%Y%m%d_%H%M%S).txt"
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Start creating the report
    echo "===== BLOCKLIST APPLIED =====" > "$REPORT_FILE"
    echo "Date and Time: $CURRENT_TIME" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Websites added to blocklist:" >> "$REPORT_FILE"
    
    # Loop through each website in the blocklist
    for site in "${BLOCKLIST[@]}"; do
        echo "  Blocking: $site"
        
        # Resolve the domain to IP addresses
        ip_addresses=$(dig +short "$site" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        
        # Block traffic to each IP address on port 443 with comment tag
        for ip in $ip_addresses; do
            ufw deny out to "$ip" port 443 comment "$BLOCKLIST_TAG" > /dev/null 2>&1
        done
        
        # Add to report
        echo "  - $site" >> "$REPORT_FILE"
    done
    
    # Reload UFW to apply changes
    ufw reload
    
    echo ""
    echo "✓ BLOCKLIST APPLIED SUCCESSFULLY"
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
    echo "Removing blocklist..."
    
    # Remove blocklist rules
    remove_blocklist_rules_only
    
    # Reload UFW to apply changes
    ufw reload
    
    # Create warning report
    REPORT_FILE="$REPORT_DIR/blocklist_removed_$(date +%Y%m%d_%H%M%S).txt"
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "===== WARNING! =====" > "$REPORT_FILE"
    echo "Date and Time: $CURRENT_TIME" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Warning! The blocklist has been removed, all websites are now accessible." >> "$REPORT_FILE"
    
    echo ""
    echo "✓ BLOCKLIST REMOVED SUCCESSFULLY"
    echo "Report saved to: $REPORT_FILE"
}

# Main script starts here
echo "=================================="
echo "  Website Blocklist Manager"
echo "=================================="
echo ""
echo "Choose an option:"
echo "1) APPLY blocklist"
echo "2) REMOVE blocklist"
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