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

# ===== SYSTEM MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}            • SYSTEM MENU •             ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue}1${nc}] Domain Panel"
echo -e " [${blue}2${nc}] VPS Speedtest"
echo -e " [${blue}3${nc}] Configure Auto Reboot"
echo -e " [${blue}4${nc}] Restart All Services"
echo -e " [${blue}5${nc}] Check Bandwidth Usage"
echo -e " [${blue}6${nc}] Install TCP BBR"
echo -e " [${blue}7${nc}] DNS Changer"
echo ""
echo -e " [${red}0${nc}] Back to Main Menu"
echo -e " [x] Exit"
echo ""
echo -e "${red}=========================================${nc}"
echo ""

read -rp " Select menu : " opt
echo ""

case $opt in
    1) clear ; m-domain ;;        # Domain Panel
    2) clear ; speedtest ;;       # VPS Speedtest
    3) clear ; auto-reboot ;;     # Configure Auto Reboot
    4) clear ; restart ;;         # Restart Services
    5) clear ; cek-bw ;;          # Check Bandwidth
    6) clear ; m-tcp ;;           # Install TCP BBR
    7) clear ; m-dns ;;           # DNS Changer
    0) clear ; menu ;;            # Back to Main Menu
    x|X) exit 0 ;;                # Exit
    *) 
        echo -e "${red}[Error]${nc} Invalid option!"
        sleep 1
        m-system
        ;;
esac
