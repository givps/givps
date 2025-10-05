#!/bin/bash
# =========================================
# Name    : ssh-user-list
# Title   : Auto Script VPS to List SSH User Details
# Version : 1.1 (Revised for Clarity and Robustness)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

echo -e "${red}=========================================${nc}"
echo -e "${blue}            SSH USERS LIST           ${nc}"
echo -e "${red}=========================================${nc}"
printf "%-17s %-20s %-10s\n" "USERNAME" "EXP DATE" "STATUS"
echo -e "${red}=========================================${nc}"

# Initialize counter
TOTAL=0

# Loop through accounts in /etc/passwd
# Filter for UID >= 1000 and exclude common system/daemon users like 'nobody'
while IFS=: read -r user _ uid _ _ _ _
do
    # Check if UID is 1000 or greater AND the user is not 'nobody' or 'nologin' shell
    if [[ $uid -ge 1000 && "$user" != "nobody" && "$user" != "nologin" ]]; then
        
        # --- 1. Get Expiration Date ---
        # Get 'Account expires' and clean up the string. Suppress errors if user is invalid/deleted mid-run.
        exp_raw=$(chage -l "$user" 2>/dev/null | grep "Account expires" | awk -F": " '{print $2}')
        # Check for 'never' or empty date
        if [[ "$exp_raw" == "never" || -z "$exp_raw" ]]; then
            EXP_DATE="${yellow}Never${nc}"
        else
            EXP_DATE="$exp_raw"
        fi

        # --- 2. Get Account Status (L=Locked, P=Password Set, NP=No Password) ---
        STATUS_CODE=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
        
        if [[ "$STATUS_CODE" == "L" ]]; then
            STATUS_MSG="${red}LOCKED${nc}"
        elif [[ "$STATUS_CODE" == "NP" ]]; then
            STATUS_MSG="${yellow}NO PASS${nc}"
        else
            STATUS_MSG="${green}ACTIVE${nc}"
        fi
        
        # --- 3. Print Output ---
        printf "%-17s %-20s %s\n" "$user" "$EXP_DATE" "$STATUS_MSG"
        
        # Increment total counter
        TOTAL=$((TOTAL + 1))
    fi
done < /etc/passwd

echo -e "${red}=========================================${nc}"
echo "Total accounts : ${green}$TOTAL user(s)${nc}"
echo -e "${red}=========================================${nc}"

read -n 1 -s -r -p "Press any key to return to the menu..."
# Execute the presumed main menu function
m-sshovpn 2>/dev/null || exit 0