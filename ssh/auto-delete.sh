#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS to Create VPN on Debian & Ubuntu Server
# Version : 1.0
# Author  : gilper0x
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # Reset color

# Detect VPS IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

today=$(date +%d-%m-%Y)

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}              ⇱ AUTO DELETE ⇲             ${nc}"
echo -e "${red}=========================================${nc}"  
echo "Checking and removing expired SSH users..."
echo -e "${red}=========================================${nc}"  

# Log files
ALLUSER_LOG="/usr/local/bin/alluser"
DELETED_LOG="/usr/local/bin/deleteduser"
: > "$ALLUSER_LOG"
: > "$DELETED_LOG"

# Process users from /etc/shadow
while IFS=: read -r username _ lastchg min max warn inactive expire rest; do
    # Skip invalid or system accounts
    [[ -z "$max" || "$max" == "" ]] && continue

    # Calculate expiration date
    user_expire_sec=$(( (lastchg + max) * 86400 ))
    expire_date=$(date -d @"$user_expire_sec" +"%d %b %Y")
    now_sec=$(date +%s)

    # Format username (fixed width for logs)
    padded_user=$(printf "%-15s" "$username")

    # Log all users with expiration info
    echo "User: $padded_user | Expires on: $expire_date" >> "$ALLUSER_LOG"

    # Check if expired
    if (( user_expire_sec < now_sec )); then
        echo "Expired user: $username | Expired on: $expire_date | Removed on: $today" >> "$DELETED_LOG"
        echo "⚠️  User $username expired ($expire_date) → removed on $today"
        userdel -r "$username" 2>/dev/null || true
    fi
done < /etc/shadow

echo -e "${red}=========================================${nc}"
echo "✅ Expired users cleanup completed."
echo -e "${red}=========================================${nc}"

read -n 1 -s -r -p "Press any key to return to menu..."
m-sshovpn
