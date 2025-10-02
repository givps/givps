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

# ===== SHADOWSOCKS MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}       • SHADOWSOCKS MENU •        ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue}1${nc}] Create Shadowsocks Account"
echo -e " [${blue}2${nc}] Create Trial Shadowsocks Account"
echo -e " [${blue}3${nc}] Extend Shadowsocks Account"
echo -e " [${blue}4${nc}] Delete Shadowsocks Account"
echo -e " [${blue}5${nc}] Check Shadowsocks Logins"
echo -e " [${blue}6${nc}] List Created Shadowsocks Accounts"
echo ""
echo -e " [${red}0${nc}] Back to Main Menu"
echo -e " [x] Exit"
echo ""
echo -e "${red}=========================================${nc}"
echo ""

read -rp " Select an option: " opt
echo ""

case $opt in
    1) clear ; add-ssws ;;                       # Create account
    2) clear ; trialssws ;;                      # Create trial account
    3) clear ; renew-ssws ;;                     # Extend account
    4) clear ; del-ssws ;;                       # Delete account
    5) clear ; cek-ssws ;;                       # Check logins
    6) clear ; cat /etc/log-create-shadowsocks.log ;;  # Show created accounts
    0) clear ; menu ;;                           # Back to main menu
    x|X) exit 0 ;;                               # Exit script
    *) 
        echo -e "${red}[Error]${nc} Invalid option!"
        sleep 1
        m-ssws ;;                                # Reload Shadowsocks menu
esac
