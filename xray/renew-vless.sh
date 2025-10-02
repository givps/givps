#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS - Renew VLESS Account
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
nc='\e[0m'        # No Color (reset)

# --- Get VPS IP ---
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# --- Check Existing Clients ---
NUMBER_OF_CLIENTS=$(grep -c -E "^#& " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          ⇱ RENEW VLESS ⇲           ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo "  • You have no existing VLESS clients!"
    echo ""
    echo -e "${red}=========================================${nc}"
    read -n 1 -s -r -p "   Press any key to return to menu"
    m-vless
fi

# --- Show Clients ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}          ⇱ RENEW VLESS ⇲           ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
grep -E "^#& " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq
echo ""
echo -e "${red}=========================================${nc}"
read -rp "   Input Username : " user

if [[ -z "$user" ]]; then
    m-vless
else
    read -rp "   Extend (days) : " expired

    # Get current expiration date
    exp=$(grep -wE "^#& $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    now=$(date +%Y-%m-%d)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    exp3=$((exp2 + expired))
    exp4=$(date -d "$exp3 days" +"%Y-%m-%d")

    # Update config
    sed -i "/#& $user/c\#& $user $exp4" /etc/xray/config.json
    systemctl restart xray > /dev/null 2>&1

    # --- Result ---
    clear
    echo -e "${red}=========================================${nc}"
    echo "   VLESS Account Has Been Successfully Renewed"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo "   • Client Name : $user"
    echo "   • Expired On  : $exp4"
    echo ""
    echo -e "${red}=========================================${nc}"
    read -n 1 -s -r -p "   Press any key to return to menu"
    m-vless
fi
