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

# ===== VMESS MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}            • VMESS MENU •          ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue}1${nc}] Create VMess Account"
echo -e " [${blue}2${nc}] Create Trial VMess Account"
echo -e " [${blue}3${nc}] Extend VMess Account"
echo -e " [${blue}4${nc}] Delete VMess Account"
echo -e " [${blue}5${nc}] Check VMess Logins"
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
    1) clear ; add-ws ;;                        # Create VMess account
    2) clear ; trialvmess ;;                    # Create trial VMess account
    3) clear ; renew-ws ;;                      # Extend VMess account
    4) clear ; del-ws ;;                        # Delete VMess account
    5) clear ; cek-ws ;;                        # Check VMess logins
    6) clear ; cat /etc/log-create-vmess.log ;; # Show created accounts
    0) clear ; menu ;;                          # Back to main menu
    x|X) exit 0 ;;                              # Exit script
    *) 
        echo -e "${red}[Error]${nc} Invalid option!"
        sleep 1
        m-vmess ;;                              # Reload VMess menu
esac
