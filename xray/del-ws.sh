#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For Create VPN on Debian & Ubuntu Server
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

config="/etc/xray/config.json"

# --- Count Clients ---
NUMBER_OF_CLIENTS=$(grep -c -E "^#! " "$config")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        ⇱ Delete Vmess Account ⇲        ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "  • No existing clients found!"
    echo -e "${red}=========================================${nc}" 
    echo ""
    read -n 1 -s -r -p "   Press any key to return to menu"
    m-vmess
fi

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}        ⇱ Delete Vmess Account ⇲        ${nc}"
echo -e "${red}=========================================${nc}"
grep -E "^### " "$config" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
echo ""
echo -e "  • [NOTE] Press Enter without input to return to menu"
echo -e "${red}=========================================${nc}"

# --- Ask Username ---
read -rp "   Input Username : " user
if [ -z "$user" ]; then
    m-vmess
fi

# --- Check if Username Exists ---
if ! grep -qwE "^### $user" "$config"; then
    echo -e "\n   • Username not found!"
    read -n 1 -s -r -p "   Press any key to return to menu"
    m-vmess
    exit
fi

# --- Get Expiration Date ---
exp=$(grep -wE "^### $user" "$config" | cut -d ' ' -f 3 | sort | uniq)

# --- Remove User Block ---
sed -i "/^### $user $exp/,/^\}/d" "$config"
systemctl restart xray > /dev/null 2>&1

# --- Success Message ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}        ⇱ Delete Vmess Account ⇲        ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "   • Account Deleted Successfully"
echo ""
echo -e "   • Client Name : $user"
echo -e "   • Expired On  : $exp"
echo -e "${red}=========================================${nc}" 
echo ""
read -n 1 -s -r -p "   Press any key to return to menu"
m-vmess
