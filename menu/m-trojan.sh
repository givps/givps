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

# ===== TROJAN MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}           • TROJAN MENU •          ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue}1${nc}] Create Trojan Account"
echo -e " [${blue}2${nc}] Create Trial Trojan Account"
echo -e " [${blue}3${nc}] Extend Trojan Account"
echo -e " [${blue}4${nc}] Delete Trojan Account"
echo -e " [${blue}5${nc}] Check Trojan Logins"
echo -e " [${blue}6${nc}] List Created Accounts"
echo ""
echo -e " [${red}0${nc}] Back to Main Menu"
echo -e " [x] Exit"
echo ""
echo -e "${red}=========================================${nc}"
echo ""

read -rp " Select an option: " opt
echo ""

case $opt in
    1) clear ; add-tr ;;                        # Create Trojan account
    2) clear ; trialtrojan ;;                   # Create trial Trojan account
    3) clear ; renew-tr ;;                      # Extend Trojan account
    4) clear ; del-tr ;;                        # Delete Trojan account
    5) clear ; cek-tr ;;                        # Check Trojan logins
    6) clear ; cat /etc/log-create-trojan.log ;; # Show created accounts log
    0) clear ; menu ;;                          # Back to main menu
    x|X) exit 0 ;;                              # Exit script
    *) 
        echo -e "${red}[Error]${nc} Invalid option!"
        sleep 1
        m-trojan ;;                             # Reload Trojan menu
esac
