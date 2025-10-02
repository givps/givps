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

# ===== DOMAIN MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}           • DOMAIN MENU •          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue}  • Don't Forget to RENEW CERTIFICATE •  ${nc}"
echo -e "${blue}        • After Changing Domain •        ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue}1${nc}] Change VPS Domain"
echo -e " [${blue}2${nc}] Renew Domain Certificate"
echo ""
echo -e " [${red}0${nc}] Back to System Menu"
echo -e " [x] Exit"
echo ""
echo -e "${red}=========================================${nc}"
echo ""

read -rp " Select an option: " opt
echo ""

case $opt in
    1) clear ; add-host ;;         # Call function to change VPS domain
    2) clear ; xray-crt ;;         # Call function to renew certificate
    0) clear ; m-system ;;          # Return to main system menu
    x|X) exit 0 ;;                  # Exit script
    *) 
       echo -e "${red}[Error]${nc} Invalid option!"
       sleep 1
       m-domain ;;                   # Reload domain menu
esac
