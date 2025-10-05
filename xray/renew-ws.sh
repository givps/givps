#!/bin/bash
# =========================================
# Name    : renew-vmess
# Title   : Auto Script VPS - Renew VMESS Account
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

USER_FILE="/etc/xray/vmess-users"

# --- Function to return to menu ---
return_to_menu() {
    if declare -f m-vmess >/dev/null 2>&1; then m-vmess; else exit 0; fi
}

# --- Check for existing users ---
if [[ ! -f "$USER_FILE" ]] || [[ ! -s "$USER_FILE" ]]; then
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          ⇱ RENEW VMESS ⇲           ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo "  • ${yellow}You have no existing VMESS clients!${nc}"
    echo ""
    echo -e "${red}=========================================${nc}"
    read -n 1 -s -r -p "Press any key to return to menu..."
    return_to_menu
fi

# --- Display user list ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}          ⇱ RENEW VMESS ⇲           ${nc}"
echo -e "${red}=========================================${nc}"
echo "  #    User        UUID        Expired"
echo -e "${red}=========================================${nc}"
# User file format: user uuid expired
mapfile -t USER_LIST < <(awk '{print $1}' "$USER_FILE")
awk '{printf "  %s.  %s\t%s\t%s\n", NR, $1, $2, $3}' "$USER_FILE" | column -t
echo ""
echo -e "  • [NOTE] Press ENTER without input to return to menu."
echo -e "${red}=========================================${nc}"

# --- Input username/number ---
read -rp "Input Username or Number: " selection

if [[ -z "$selection" ]]; then
    return_to_menu
fi

# Determine selected user
selected_user=""
if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -gt 0 ]] && [[ "$selection" -le ${#USER_LIST[@]} ]]; then
    # User selected by number
    selected_user="${USER_LIST[$selection-1]}"
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

# --- Input extension period ---
read -rp "Extend (days): " expired
# Set default to 30 days if input is empty or non-numeric
if ! [[ "$expired" =~ ^[0-9]+$ ]]; then
    expired=30
    echo -e "[ ${yellow}NOTE${nc} ] Defaulting extension to $expired days."
fi

# --- Calculate new expiry date ---
# $3 is the expiration date in /etc/xray/vmess-users
current_exp_date=$(awk -v usr="$selected_user" '$1 == usr {print $3; exit}' "$USER_FILE")
new_exp_date=$(date -d "$current_exp_date + $expired days" +"%Y-%m-%d")

# --- Get existing data ---
user_data=$(grep -E "^$selected_user " "$USER_FILE")
uuid=$(echo "$user_data" | awk '{print $2}')

# --- Update user file (Using safer temp file method) ---
echo -e "[ ${green}INFO${nc} ] Updating expiration date to $new_exp_date..."

# 1. Write the new user line to a temp file: User UUID New_Expiry
echo "$selected_user $uuid $new_exp_date" > /tmp/vmess-new

# 2. Append all other users (excluding the renewed user)
grep -v "^$selected_user " "$USER_FILE" >> /tmp/vmess-new

# 3. Replace the original file
mv /tmp/vmess-new "$USER_FILE"

# Restart Xray (optional for VMess, as UUID doesn't change, but fine for consistency)
systemctl restart xray >/dev/null 2>&1

# --- Display result ---
clear
echo -e "${red}=========================================${nc}"
echo -e "   ${green}VMESS Account Has Been Successfully Renewed!${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo "   • Client Name : ${yellow}$selected_user${nc}"
echo "   • Expired On  : ${yellow}$new_exp_date${nc}"
echo ""
echo -e "${red}=========================================${nc}"
read -n 1 -s -r -p "Press any key to return to menu..."
return_to_menu