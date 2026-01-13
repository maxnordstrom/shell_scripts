#!/usr/bin/env python3
"""
Weak Password Checker for Ubuntu Workstations
This script checks if user accounts are using weak passwords.
Must be run with sudo/root privileges.
"""

import os
import subprocess
import datetime

# Konfiguration
MIN_USER_ID = 1000
MAX_USER_ID = 60000
PASSWD_FILE = "/etc/passwd"
SHADOW_FILE = "/etc/shadow"
WORDLIST_FILE = "/usr/share/wordlists/rockyou.txt"  # Vanlig sökväg till wordlist
OUTPUT_DIR = "./reports" # Skapar en mapp i samma katalog där scriptet körs
REPORT_FILE = f"weak_password_report_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt" # Gör varje rapportnamn unikt med timestamp

def print_header():
    """Print the script header"""
    print("=" * 60)
    print("Ubuntu Workstation Weak Password Checker")
    print("=" * 60)
    print()

def check_root():
    """Check if the script is running with root privileges"""
    if os.geteuid() != 0:
        print("ERROR: This script must be run with sudo or as root!")
        print("Please run: sudo python3 weak_password_checker.py")
        exit(1)

def check_john_installed():
    """Check if John the Ripper is installed"""
    try:
        result = subprocess.run(["which", "john"], capture_output=True, text=True)
        if result.returncode != 0:
            print("ERROR: John the Ripper is not installed!")
            print("Please install it: sudo apt-get install john")
            exit(1)
    except Exception as e:
        print(f"ERROR checking for John the Ripper: {e}")
        exit(1)

def check_wordlist():
    """Check if wordlist file exists"""
    if not os.path.exists(WORDLIST_FILE):
        print(f"WARNING: Wordlist not found at {WORDLIST_FILE}")
        print("You can download rockyou.txt or use another wordlist.")
        user_input = input("Enter path to wordlist file (or press Enter to exit): ")
        if user_input.strip():
            return user_input.strip()
        else:
            exit(1)
    return WORDLIST_FILE

def get_human_users():
    """Get all human user accounts from /etc/passwd"""
    human_users = []
    
    print(f"Reading user accounts from {PASSWD_FILE}...")
    
    try:
        with open(PASSWD_FILE, "r") as file:
            for line in file:
                # Skip empty lines
                if not line.strip():
                    continue
                
                # Split the line by colon
                parts = line.strip().split(":")
                
                # Get username and user ID
                username = parts[0]
                user_id = int(parts[2])
                
                # Check if this is a human user (UID between 1000 and 60000)
                if user_id >= MIN_USER_ID and user_id <= MAX_USER_ID:
                    human_users.append(username)
    
    except Exception as e:
        print(f"ERROR reading {PASSWD_FILE}: {e}")
        exit(1)
    
    return human_users

def display_users(users):
    """Display the list of users found"""
    print(f"\nFound {len(users)} human user account(s):")
    for i, user in enumerate(users, 1):
        print(f"  {i}. {user}")
    print()

def ask_user_choice(users):
    """Ask if user wants to check specific user or all users"""
    print("What would you like to do?")
    print("1. Check ALL user accounts")
    print("2. Check a SPECIFIC user account")
    
    choice = input("\nEnter your choice (1 or 2): ").strip()
    
    if choice == "1":
        return users
    elif choice == "2":
        target_user = input("Enter the username to check: ").strip()
        if target_user in users:
            return [target_user]
        else:
            print(f"ERROR: User '{target_user}' not found in human user accounts!")
            exit(1)
    else:
        print("ERROR: Invalid choice!")
        exit(1)

def create_output_directory():
    """Create output directory for temporary files"""
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created output directory: {OUTPUT_DIR}")

def extract_shadow_entries(target_users):
    """Extract shadow file entries for target users"""
    shadow_output_file = os.path.join(OUTPUT_DIR, "shadow_extract.txt")
    
    print(f"\nExtracting password hashes from {SHADOW_FILE}...")
    
    try:
        with open(SHADOW_FILE, "r") as shadow_file:
            with open(shadow_output_file, "w") as output_file:
                for line in shadow_file:
                    # Get the username from the shadow entry
                    username = line.split(":")[0]
                    
                    # Check if this user is in our target list
                    if username in target_users:
                        output_file.write(line)
                        print(f"  Extracted entry for: {username}")
    
    except Exception as e:
        print(f"ERROR reading shadow file: {e}")
        exit(1)
    
    return shadow_output_file

def run_john_the_ripper(shadow_file, wordlist):
    """Run John the Ripper against the shadow file"""
    print("\n" + "=" * 60)
    print("Running John the Ripper password cracking...")
    print("This may take some time depending on the wordlist size.")
    print("=" * 60)
    
    # Run John the Ripper
    command = ["john", "--wordlist=" + wordlist, shadow_file]
    
    try:
        print(f"\nExecuting: {' '.join(command)}\n")
        subprocess.run(command)
    except Exception as e:
        print(f"ERROR running John the Ripper: {e}")
        exit(1)

def get_cracked_passwords(shadow_file):
    """Get the cracked passwords from John the Ripper"""
    print("\n" + "=" * 60)
    print("Retrieving cracked passwords...")
    print("=" * 60)
    
    cracked_users = []
    
    # Show cracked passwords
    command = ["john", "--show", shadow_file]
    
    try:
        result = subprocess.run(command, capture_output=True, text=True)
        output_lines = result.stdout.strip().split("\n")
        
        for line in output_lines:
            # John outputs in format: username:password:uid:gid:...
            if ":" in line and not line.startswith("0 password") and line.strip():
                username = line.split(":")[0]
                if username:
                    cracked_users.append(username)
                    print(f"  WEAK PASSWORD FOUND for user: {username}")
        
    except Exception as e:
        print(f"ERROR retrieving cracked passwords: {e}")
        exit(1)
    
    return cracked_users

def generate_report(target_users, cracked_users):
    """Generate the final report"""
    report_path = os.path.join(OUTPUT_DIR, REPORT_FILE)
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    print(f"\n{'=' * 60}")
    print("Generating report...")
    print("=" * 60)
    
    try:
        with open(report_path, "w") as report:
            report.write("=" * 60 + "\n")
            report.write("WEAK PASSWORD AUDIT REPORT\n")
            report.write("=" * 60 + "\n")
            report.write(f"Report Generated: {timestamp}\n")
            report.write(f"Total Users Checked: {len(target_users)}\n")
            report.write(f"Weak Passwords Found: {len(cracked_users)}\n")
            report.write("=" * 60 + "\n\n")
            
            if cracked_users:
                report.write("SECURITY ALERT - WEAK PASSWORDS DETECTED:\n")
                report.write("-" * 60 + "\n")
                for user in cracked_users:
                    report.write(f"* The user '{user}' is using a weak password\n")
                report.write("\n")
                report.write("ACTION REQUIRED:\n")
                report.write("These users must change their passwords immediately.\n")
                report.write("Passwords must meet company security policy requirements.\n")
            else:
                report.write("RESULT: No weak passwords detected.\n")
                report.write("All checked user accounts appear to be using strong passwords.\n")
            
            report.write("\n" + "=" * 60 + "\n")
            report.write("End of Report\n")
            report.write("=" * 60 + "\n")
    
    except Exception as e:
        print(f"ERROR generating report: {e}")
        exit(1)
    
    return report_path

def print_summary(target_users, cracked_users, report_path):
    """Print the final summary"""
    print(f"\n{'=' * 60}")
    print("AUDIT COMPLETE")
    print("=" * 60)
    print(f"Users checked: {len(target_users)}")
    print(f"Weak passwords found: {len(cracked_users)}")
    print(f"\nReport saved to: {report_path}")
    print("=" * 60)
    
    if cracked_users:
        print("\nWARNING: Weak passwords detected!")
        print("Please review the report and take immediate action.")
    else:
        print("\nGood news! No weak passwords were detected.")

def main():
    """Main function"""
    # Print header
    print_header()
    
    # Check if running as root
    check_root()
    
    # Check if John the Ripper is installed
    check_john_installed()
    
    # Check if wordlist exists
    wordlist = check_wordlist()
    
    # Get all human users
    all_users = get_human_users()
    
    if not all_users:
        print("No human user accounts found!")
        exit(0)
    
    # Display users
    display_users(all_users)
    
    # Ask what to check
    target_users = ask_user_choice(all_users)
    
    print(f"\nTarget users selected: {', '.join(target_users)}")
    
    # Create output directory
    create_output_directory()
    
    # Extract shadow entries
    shadow_file = extract_shadow_entries(target_users)
    
    # Run John the Ripper
    run_john_the_ripper(shadow_file, wordlist)
    
    # Get cracked passwords
    cracked_users = get_cracked_passwords(shadow_file)
    
    # Generate report
    report_path = generate_report(target_users, cracked_users)
    
    # Print summary
    print_summary(target_users, cracked_users, report_path)

# Run the script
if __name__ == "__main__":
    main()