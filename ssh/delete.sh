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
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

echo -e "${red}=========================================${nc}"
echo -e "${blue}            ⇱ DELETE SSH USER ⇲          ${nc}"
echo -e "${red}=========================================${nc}"
echo ""

# --- Ask for username ---
read -rp "🔑 Enter the SSH username to delete: " USERNAME

# --- Validate input ---
if [[ -z "$USERNAME" ]]; then
    echo -e "⚠️  Error: Username cannot be empty!"
else
    if id "$USERNAME" &>/dev/null; then
        sudo userdel -r "$USERNAME" &>/dev/null
        echo -e "✅ User '$USERNAME' has been deleted successfully."
    else
        echo -e "❌ Error: User '$USERNAME' does not exist on this system."
    fi
fi

echo ""
echo -e "${red}=========================================${nc}"
read -n 1 -s -r -p "Press any key to return to the menu..."
m-sshovpn
