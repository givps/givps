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

# ===== VLESS MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}            • VLESS MENU •          ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue}1${nc}] Create VLESS Account"
echo -e " [${blue}2${nc}] Create Trial VLESS Account"
echo -e " [${blue}3${nc}] Extend VLESS Account"
echo -e " [${blue}4${nc}] Delete VLESS Account"
echo -e " [${blue}5${nc}] Check VLESS Logins"
echo -e " [${blue}6${nc}] List Created Accounts"
echo ""
echo -e " [${red}0${nc}] Back to Main Menu"
echo -e " [x] Exit"
echo ""
echo -e "${red}=========================================${nc}"
echo -ne " Select an option: "

read opt
echo ""

case $opt in
    1) clear ; add-vless ;;                    # Create VLESS account
    2) clear ; trialvless ;;                   # Create trial VLESS account
    3) clear ; renew-vless ;;                  # Extend VLESS account
    4) clear ; del-vless ;;                    # Delete VLESS account
    5) clear ; cek-vless ;;                    # Check VLESS logins
    6) clear ; cat /etc/log-create-vless.log ;; # Show created accounts
    0) clear ; menu ;;                         # Back to main menu
    x|X) exit 0 ;;                             # Exit script
    *) 
        echo -e "${red}[Error]${nc} Invalid option!"
        sleep 1
        m-vless ;;                             # Reload VLESS menu
esac
