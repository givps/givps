#!/bin/bash
# =========================================
# Name    : del-ss
# Title   : Auto Script VPS - Delete Shadowsocks Account
# Version : 1.2 (Revised)
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

clear
echo -e "${green}Checking VPS...${nc}"
sleep 0.5

USER_FILE="/etc/shadowsocks/ss-users"
CONFIG="/etc/xray/config.json"

# --- Function to return to menu ---
return_to_menu() {
    if declare -f m-ssws >/dev/null 2>&1; then m-ssws; else exit 0; fi
}

# --- Check for existing users ---
if [[ ! -f "$USER_FILE" ]] || [[ ! -s "$USER_FILE" ]]; then
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}      ⇱ Delete Shadowsocks Account ⇲     ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo "  • ${yellow}No existing Shadowsocks clients found!${nc}"
    echo ""
    echo -e "${red}=========================================${nc}"
    read -n 1 -s -r -p "Press any key to return to menu..."
    return_to_menu
fi

# --- Display user list ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}      ⇱ Delete Shadowsocks Account ⇲     ${nc}"
echo -e "${red}=========================================${nc}"
echo "  #    User        UUID        Expired"
echo -e "${red}=========================================${nc}"
# Display format: #. User Expired
mapfile -t USER_LIST < <(awk '{print $1 " " $4}' "$USER_FILE")
awk '{print "  " NR ". " $0}' "$USER_FILE" | awk '{printf "  %s  %s\t%s\t%s\n", $1, $2, $3, $4}' | column -t
echo ""
echo -e "  • [NOTE] Press ENTER without input to return to menu."
echo -e "${red}=========================================${nc}"

# --- Input username/number ---
read -rp "Input Username or Number : " selection

if [[ -z "$selection" ]]; then
    return_to_menu
fi

# Determine selected user
selected_user=""
if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -gt 0 ]] && [[ "$selection" -le ${#USER_LIST[@]} ]]; then
    # User selected by number
    selected_user=$(echo "${USER_LIST[$selection-1]}" | awk '{print $1}')
else
    # User input username directly
    selected_user="$selection"
fi

# --- Check if the user exists ---
if ! grep -q "^$selected_user " "$USER_FILE"; then
    echo -e "\n${red}❌ User '$selected_user' not found!${nc}"
    sleep 2
    return_to_menu
fi

# --- Deletion Process ---

# 1. Delete from user database
echo -e "[ ${green}INFO${nc} ] Deleting user $selected_user from database..."
grep -v "^$selected_user " "$USER_FILE" > /tmp/ss-new
mv /tmp/ss-new "$USER_FILE"

# 2. Delete from config.json
if command -v jq &> /dev/null; then
    echo -e "[ ${green}INFO${nc} ] Deleting client from Xray config..."
    if ! jq --arg u "$selected_user" 'del(.inbounds[]?.settings.clients[]? | select(.email == $u))' "$CONFIG" > "$CONFIG.tmp"; then
        echo -e "${red}❌ ERROR: Failed to process config.json with jq. Config not updated!${nc}"
        rm -f "$CONFIG.tmp"
        sleep 2
        return_to_menu
    fi
    mv "$CONFIG.tmp" "$CONFIG"
else
    echo -e "${yellow}Warning: 'jq' not installed. Manual config cleanup required.${nc}"
fi

# 3. Restart Xray
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray >/dev/null 2>&1

# --- Display result ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}      ⇱ Delete Shadowsocks Account ⇲     ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "   • ${green}Account Deleted Successfully!${nc}"
echo ""
echo -e "   • Client Name : ${yellow}$selected_user${nc}"
echo -e "${red}=========================================${nc}"
echo ""
read -n 1 -s -r -p "Press any key to return to menu..."
return_to_menu