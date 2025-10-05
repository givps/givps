#!/bin/bash
# =========================================
# Name    : renew-user
# Title   : Auto Script VPS to Renew/Extend VPN/SSH User Expiration
# Version : 1.1 (Revised to Calculate Extension from Current Expiration)
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

# Detect VPS Public IP (Not strictly needed, but kept for context)
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

echo -e "${red}=========================================${nc}"
echo -e "${blue}               RENEW  USER                ${nc}"
echo -e "${red}=========================================${nc}"
echo

# --- 1. Get Username ---
read -rp "Username : " User

# --- 2. Validate User Existence ---
if ! id "$User" &>/dev/null; then
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}               RENEW  USER                ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "\n   ${red}❌ Username [$User] does not exist${nc}"
    echo -e "\n${red}=========================================${nc}"
    read -n 1 -s -r -p "Press any key to return to menu..."
    m-sshovpn 2>/dev/null || exit 0
fi

# --- 3. Get Days to Extend ---
read -rp "Extend (days): " Days

if [[ -z "$Days" || ! "$Days" =~ ^[0-9]+$ || "$Days" -le 0 ]]; then
    echo -e "${red}❌ Invalid number of days! Must be a positive integer.${nc}"
    exit 1
fi

# --- 4. Calculate New Expiration Date ---

# Get current expiration date in YYYY-MM-DD format (or "never" / empty)
CURRENT_EXP_RAW=$(chage -l "$User" | grep "Account expires" | awk -F": " '{print $2}')

# Determine the start date for the extension calculation
if [[ "$CURRENT_EXP_RAW" == "never" || -z "$CURRENT_EXP_RAW" || "$CURRENT_EXP_RAW" == "Jan 1, 1970" ]]; then
    # If currently not set or expired, start calculation from Today
    START_DATE="today"
    echo -e "${yellow}[INFO] Starting renewal calculation from today.${nc}"
else
    # Convert current expiration date to seconds since epoch
    # We use +1 day to ensure the new extension starts AFTER the current expiration ends.
    # We suppress date errors (due to locale differences)
    CURRENT_EXP_SEC=$(date -d "$CURRENT_EXP_RAW" +%s 2>/dev/null)
    TODAY_SEC=$(date +%s)

    if [[ "$CURRENT_EXP_SEC" -gt "$TODAY_SEC" ]]; then
        # If the account is still valid, extend from the current expiration date
        START_DATE="$CURRENT_EXP_RAW"
        echo -e "${green}[INFO] Extending from current expiration date: $CURRENT_EXP_RAW${nc}"
    else
        # If the account is already expired, extend from Today
        START_DATE="today"
        echo -e "${yellow}[INFO] Account is expired. Starting renewal calculation from today.${nc}"
    fi
fi

# Calculate the new expiration date
# Use 'date' command to add the days to the determined START_DATE
Expiration=$(date -d "$START_DATE + $Days days" +%Y-%m-%d)
Expiration_Display=$(date -d "$START_DATE + $Days days" '+%d %b %Y')

# --- 5. Apply Changes ---

# Renew user (ensure account is unlocked)
passwd -u "$User" >/dev/null 2>&1
# Set the new expiration date
usermod -e "$Expiration" "$User"

# --- 6. Final Output ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}             USER RENEWED               ${nc}"
echo -e "${red}=========================================${nc}"
echo -e ""
echo -e " Username    : ${green}$User${nc}"
echo -e " Days Added  : ${green}$Days Day(s)${nc}"
echo -e " Expires On  : ${green}$Expiration_Display${nc} (${Expiration})"
echo -e ""
echo -e "${red}=========================================${nc}"

read -n 1 -s -r -p "Press any key to return to menu..."
m-sshovpn 2>/dev/null || exit 0