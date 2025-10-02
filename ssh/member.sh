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
echo -e "${blue}               SSH USERS LIST             ${nc}"
echo -e "${red}=========================================${nc}"
printf "%-17s %-20s %-10s\n" "USERNAME" "EXP DATE" "STATUS"
echo -e "${red}=========================================${nc}"

# Loop through accounts in /etc/passwd
while IFS=: read -r user _ uid _ _ _ _
do
    if [[ $uid -ge 1000 && "$user" != "nobody" ]]; then
        exp=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
        status=$(passwd -S "$user" | awk '{print $2}')

        if [[ "$status" == "L" ]]; then
            printf "%-17s %-20s ${red}LOCKED${nc}\n" "$user" "$exp"
        else
            printf "%-17s %-20s ${green}ACTIVE${nc}\n" "$user" "$exp"
        fi
    fi
done < /etc/passwd

# Count number of accounts
TOTAL=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)

echo -e "${red}=========================================${nc}"
echo "Total accounts : $TOTAL user(s)"
echo -e "${red}=========================================${nc}"

read -n 1 -s -r -p "Press any key to return to the menu..."
m-sshovpn
