#!/bin/bash

# Website Whitelist Script for UFW
# This script applies or removes a website whitelist using UFW firewall
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

# Path to whitelist file
WHITELIST_FILE="./whitelist.txt"

# Check if whitelist file exists
if [ ! -f "$WHITELIST_FILE" ]; then
    echo "ERROR: Whitelist file not found: $WHITELIST_FILE"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Read whitelist from file into array
mapfile -t WHITELIST < "$WHITELIST_FILE"

# Create reports directory if it doesn't exist
REPORT_DIR="./reports"
if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR"
fi

# Tag used to identify whitelist rules
WHITELIST_TAG="WHITELIST_RULE"

# Function to apply the whitelist
apply_whitelist() {
    echo "Applying whitelist..."
    
    # Enable UFW if not already enabled
    ufw --force enable
    
    # Set default policy to deny all outgoing traffic
    ufw default deny outgoing > /dev/null 2>&1
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow routed > /dev/null 2>&1
    
    # Allow local network traffic with comment tag
    ufw allow out on lo comment "$WHITELIST_TAG" > /dev/null 2>&1
    ufw allow in on lo comment "$WHITELIST_TAG" > /dev/null 2>&1
    
    # Allow DNS (needed to resolve domain names) with comment tag
    ufw allow out 53 comment "$WHITELIST_TAG" > /dev/null 2>&1

    # Allow HTTP and HTTPS (needed to access websites) with comment tag
    ufw allow out 80 comment "$WHITELIST_TAG" > /dev/null 2>&1
    ufw allow out 443 comment "$WHITELIST_TAG" > /dev/null 2>&1
    
    # Variables for the report
    REPORT_FILE="$REPORT_DIR/whitelist_report_$(date +%Y%m%d_%H%M%S).txt"
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Start creating the report
    echo "===== WHITELIST APPLIED =====" > "$REPORT_FILE"
    echo "Date and Time: $CURRENT_TIME" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Websites added to whitelist:" >> "$REPORT_FILE"
    
    # Loop through each website in the whitelist
    for site in "${WHITELIST[@]}"; do
        echo "  Adding: $site"
        
        # Resolve the domain to IP addresses
        ip_addresses=$(dig +short "$site" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        
        # Allow traffic to each IP address with comment tag
        for ip in $ip_addresses; do
            ufw allow out to "$ip" comment "$WHITELIST_TAG" > /dev/null 2>&1
        done
        
        # Add to report
        echo "  - $site" >> "$REPORT_FILE"
    done
    
    # Reload UFW to apply changes
    ufw reload
    
    echo ""
    echo "✓ WHITELIST APPLIED SUCCESSFULLY"
    echo "Report saved to: $REPORT_FILE"
}

# Function to remove only whitelist rules
remove_whitelist_rules_only() {
    # Get all rule numbers with the whitelist tag (in reverse order)
    rule_numbers=$(ufw status numbered | grep "$WHITELIST_TAG" | awk -F'[][]' '{print $2}' | sort -rn)
    
    # Delete each rule by number
    for rule_num in $rule_numbers; do
        echo "  Removing rule $rule_num"
        ufw --force delete "$rule_num"
    done
}

# Function to remove the whitelist
remove_whitelist() {
    echo "Removing whitelist..."
    
    # Remove whitelist rules
    remove_whitelist_rules_only
    
    # Reload UFW to apply changes
    ufw reload
    
    # Create warning report
    REPORT_FILE="$REPORT_DIR/whitelist_removed_$(date +%Y%m%d_%H%M%S).txt"
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "===== WARNING! =====" > "$REPORT_FILE"
    echo "Date and Time: $CURRENT_TIME" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Warning! The whitelist has been removed, all websites are now accessible." >> "$REPORT_FILE"
    
    echo ""
    echo "✓ WHITELIST REMOVED SUCCESSFULLY"
    echo "Report saved to: $REPORT_FILE"
}

# Main script starts here
echo "=================================="
echo "  Website Whitelist Manager"
echo "=================================="
echo ""
echo "Choose an option:"
echo "1) APPLY whitelist"
echo "2) REMOVE whitelist"
echo ""
read -r -p "Enter your choice (1 or 2): " choice

# Process user choice
if [ "$choice" = "1" ]; then
    apply_whitelist
elif [ "$choice" = "2" ]; then
    remove_whitelist
else
    echo "ERROR: Invalid choice. Please run the script again and choose 1 or 2."
    exit 1
fi

echo ""
echo "Done!"