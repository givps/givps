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
echo -e "${blue}               RENEW  USER                ${nc}"
echo -e "${red}=========================================${nc}"
echo

read -p "Username : " User
if id "$User" &>/dev/null; then
    read -p "Extend (days): " Days

    if [[ -z "$Days" || ! "$Days" =~ ^[0-9]+$ ]]; then
        echo "❌ Invalid number of days!"
        exit 1
    fi

    Today=$(date +%s)
    Extend=$(( Days * 86400 ))
    Expire_On=$(( Today + Extend ))

    Expiration=$(date -d @"$Expire_On" +%Y-%m-%d)
    Expiration_Display=$(date -d @"$Expire_On" '+%d %b %Y')

    # Renew user
    passwd -u "$User" >/dev/null 2>&1
    usermod -e "$Expiration" "$User"

    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}               RENEW  USER                ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    echo -e " Username   : $User"
    echo -e " Days Added : $Days Day(s)"
    echo -e " Expires On : $Expiration_Display"
    echo -e ""
    echo -e "${red}=========================================${nc}"
else
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}               RENEW  USER                ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    echo -e "   ❌ Username [$User] does not exist"
    echo -e ""
    echo -e "${red}=========================================${nc}"
fi

read -n 1 -s -r -p "Press any key to return to menu..."
m-sshovpn
