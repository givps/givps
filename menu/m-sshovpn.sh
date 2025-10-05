#!/bin/bash
# =========================================
# Name    : ssh-menu
# Title   : Interactive Menu for SSH/WebSocket Account Management
# Version : 1.1 (Safety and Flow Fixes)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

LOG_FILE="/etc/log-create-ssh.log"
BANNER_FILE="/etc/issue.net"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Main Menu Loop ---
while true; do
    clear
    
    # ===== SSH MENU =====
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}            • SSH/WS MENU •         ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo -e " [${blue} 1${nc}] Create SSH & WS Account (usernew)"
    echo -e " [${blue} 2${nc}] Create Trial SSH & WS Account (trial)"
    echo -e " [${blue} 3${nc}] Renew SSH & WS Account (renew)"
    echo -e " [${blue} 4${nc}] Delete SSH & WS Account (delete)"
    echo -e " [${blue} 5${nc}] Check SSH & WS User Login (cek)"
    echo -e " [${blue} 6${nc}] List SSH & WS Members (member)"
    echo -e " [${blue} 7${nc}] Auto Delete Expired Users (auto-delete)"
    echo -e " [${blue} 8${nc}] Set SSH Auto-Kill Session Limit (auto-kill)"
    echo -e " [${blue} 9${nc}] Check Multi-Login Users (cek-user)"
    echo -e " [${blue}10${nc}] Show Created SSH Accounts Log"
    echo -e " [${blue}11${nc}] Change SSH Banner"
    echo -e " [${blue}12${nc}] Lock/Unlock SSH User (user-lockunlock)"
    echo ""
    echo -e " [${red} 0${nc}] Back to Main Menu"
    echo -e " [x] Exit"
    echo ""
    echo -e "${red}=========================================${nc}"
    echo ""

    read -rp " Select an option: " opt
    echo ""

    case "$opt" in
        1) clear ; usernew ;;
        2) clear ; trial ;;
        3) clear ; renew ;;
        4) clear ; delete ;;
        5) clear ; cek ;;
        6) clear ; member ;;
        7) clear ; auto-delete ;;
        8) clear ; auto-kill ;;
        9) clear ; cek-user ;;
        10) 
            clear
            echo -e "${yellow}--- CREATED SSH ACCOUNTS LOG ---${nc}"
            if [ -f "$LOG_FILE" ]; then
                cat "$LOG_FILE"
            else
                echo -e "${red}Error:${nc} Log file $LOG_FILE not found."
            fi
            echo -e "${red}=========================================${nc}"
            read -n 1 -s -r -p "Press any key to return to the menu..."
            ;;
        11) 
            clear
            if command -v nano >/dev/null; then
                echo -e "${yellow}Opening $BANNER_FILE with nano...${nc}"
                nano "$BANNER_FILE"
                read -n 1 -s -r -p "Press any key to return to the menu..."
            else
                echo -e "${red}Error:${nc} Nano editor not found. Please install nano or edit $BANNER_FILE manually."
                read -n 1 -s -r -p "Press any key to return to the menu..."
            fi
            ;;
        12) clear ; user-lockunlock ;;
        0) 
            clear
            # Call parent menu function if it exists, otherwise exit
            menu 2>/dev/null || exit 0
            ;;
        x|X) exit 0 ;;
        *) 
           echo -e "${red}[Error]${nc} Invalid option! Please select 0-12 or x."
           sleep 1
           ;;
    esac
done