#!/bin/bash
# =========================================
# Name    : auto-del-expired-users
# Title   : Auto Script VPS to Delete Expired SSH Users
# Version : 1.1 (Revised for Robustness)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # Reset color

# --- Configuration ---
TODAY=$(date +%d-%m-%Y)
NOW_SEC=$(date +%s)
ALLUSER_LOG="/usr/local/bin/alluser.log"
DELETED_LOG="/usr/local/bin/deleteduser.log"

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}              ⇱ AUTO DELETE ⇲             ${nc}"
echo -e "${red}=========================================${nc}"  
echo "Checking and removing expired SSH users..."
echo -e "${red}=========================================${nc}"  

# Clear log files for the new run
: > "$ALLUSER_LOG"
: > "$DELETED_LOG"
echo "Log files cleared: $ALLUSER_LOG and $DELETED_LOG"

# --- Main Processing ---
# Iterate through users in /etc/shadow and /etc/passwd simultaneously
# to get both expiration data and UID for filtering.
while IFS=: read -r username password_hash lastchg min max warn inactive expire rest; do
    
    # Check UID from /etc/passwd (System users typically have UID < 1000)
    USER_UID=$(id -u "$username" 2>/dev/null)
    if [[ -z "$USER_UID" ]] || (( USER_UID < 1000 )); then
        continue # Skip system users and non-existent users
    fi

    # Check if 'max' password lifetime is set (0 means never expires, empty means invalid/system)
    [[ -z "$max" || "$max" == "0" ]] && continue

    # Calculate expiration date in seconds and human-readable format
    USER_EXPIRE_SEC=$(( (lastchg + max) * 86400 ))
    EXPIRE_DATE=$(date -d @"$USER_EXPIRE_SEC" +"%d %b %Y")
    
    # Format username for clean logging (fixed width)
    PADDED_USER=$(printf "%-15s" "$username")

    # Log all relevant users with expiration info
    echo "User: $PADDED_USER | UID: $USER_UID | Expires on: $EXPIRE_DATE" >> "$ALLUSER_LOG"

    # Check if the user is expired (Expiration time < Current time)
    if (( USER_EXPIRE_SEC < NOW_SEC )); then
        
        # --- Deletion ---
        if userdel -r "$username" 2>/dev/null; then
            echo "✅ User $username expired ($EXPIRE_DATE) → REMOVED successfully."
            echo "Expired user: $username | Expired on: $EXPIRE_DATE | Removed on: $TODAY" >> "$DELETED_LOG"
        else
            echo "❌ Failed to remove user $username. Check logs."
        fi
    fi

done < /etc/shadow

echo -e "${red}=========================================${nc}"
echo "✅ Expired users cleanup completed."
echo "Full list of users processed: $ALLUSER_LOG"
echo "List of deleted users: $DELETED_LOG"
echo -e "${red}=========================================${nc}"

# --- Return to menu logic (assumes m-sshovpn is a defined function) ---
read -n 1 -s -r -p "Press any key to return to menu..."
m-sshovpn 2>/dev/null || exit 0 # Execute m-sshovpn if it exists, otherwise exit