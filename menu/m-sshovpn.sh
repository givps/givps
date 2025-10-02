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

# ===== SSH MENU =====
echo -e "${red}=========================================${nc}"
echo -e "${blue}            • SSH MENU •            ${nc}"
echo -e "${red}=========================================${nc}"
echo ""
echo -e " [${blue} 1${nc}] Create SSH & WS Account"
echo -e " [${blue} 2${nc}] Create Trial SSH & WS Account"
echo -e " [${blue} 3${nc}] Renew SSH & WS Account"
echo -e " [${blue} 4${nc}] Delete SSH & WS Account"
echo -e " [${blue} 5${nc}] Check SSH & WS User Login"
echo -e " [${blue} 6${nc}] List SSH & WS Members"
echo -e " [${blue} 7${nc}] Auto Delete Expired SSH & WS Users"
echo -e " [${blue} 8${nc}] Set SSH Auto-Kill"
echo -e " [${blue} 9${nc}] Check Multi-Login Users"
echo -e " [${blue}10${nc}] Show Created SSH Accounts"
echo -e " [${blue}11${nc}] Change SSH Banner"
echo -e " [${blue}12${nc}] Lock/Unlock SSH User"
echo ""
echo -e " [${red} 0${nc}] Back to Main Menu"
echo -e " [x] Exit"
echo ""
echo -e "${red}=========================================${nc}"
echo ""

read -rp " Select an option: " opt
echo ""

case $opt in
    1) clear ; usernew ;;          # Create new SSH & WebSocket account
    2) clear ; trial ;;            # Create trial account
    3) clear ; renew ;;            # Renew account
    4) clear ; delete ;;           # Delete account
    5) clear ; cek ;;              # Check user login
    6) clear ; member ;;           # List all members
    7) clear ; auto-delete ;;      # Auto delete expired users
    8) clear ; auto-kill ;;        # Set auto-kill for SSH
    9) clear ; cek-user ;;         # Check multi-login users
   10) clear ; cat /etc/log-create-ssh.log ;;  # Show created accounts log
   11) clear ; nano /etc/issue.net ;;         # Edit SSH banner
   12) clear ; user-lockunlock ;;             # Lock or unlock SSH user
    0) clear ; menu ;;             # Return to main menu
    x|X) exit 0 ;;                 # Exit script
    *) 
       echo -e "${red}[Error]${nc} Invalid option!"
       sleep 1
       m-sshovpn ;;                 # Reload SSH menu
esac
