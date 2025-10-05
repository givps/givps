#!/bin/bash
# =========================================
# Name    : trojan-menu
# Title   : Interactive Menu for Trojan Account Management
# Version : 1.1 (Safety and Flow Fixes)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

TROJAN_LOG_FILE="/etc/log-create-trojan.log"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Main Menu Loop ---
while true; do
    clear

    # ===== TROJAN MENU =====
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           • TROJAN MENU •          ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo -e " [${blue}1${nc}] Create Trojan Account (add-tr)"
    echo -e " [${blue}2${nc}] Create Trial Trojan Account (trialtrojan)"
    echo -e " [${blue}3${nc}] Extend Trojan Account (renew-tr)"
    echo -e " [${blue}4${nc}] Delete Trojan Account (del-tr)"
    echo -e " [${blue}5${nc}] Check Trojan Logins (cek-tr)"
    echo -e " [${blue}6${nc}] List Created Accounts Log"
    echo ""
    echo -e " [${red}0${nc}] Back to Main Menu"
    echo -e " [x] Exit"
    echo ""
    echo -e "${red}=========================================${nc}"
    echo ""

    read -rp " Select an option: " opt
    echo ""

    case "$opt" in
        1) clear ; add-tr ;;
        2) clear ; trialtrojan ;;
        3) clear ; renew-tr ;;
        4) clear ; del-tr ;;
        5) clear ; cek-tr ;;
        6) 
            clear
            echo -e "${yellow}--- CREATED TROJAN ACCOUNTS LOG ---${nc}"
            if [ -f "$TROJAN_LOG_FILE" ]; then
                cat "$TROJAN_LOG_FILE"
            else
                echo -e "${red}Error:${nc} Log file $TROJAN_LOG_FILE not found."
            fi
            echo -e "${red}=========================================${nc}"
            read -n 1 -s -r -p "Press any key to return to the menu..."
            ;;
        0) 
            clear
            # Call parent menu function if it exists, otherwise exit
            menu 2>/dev/null || exit 0
            ;;
        x|X) exit 0 ;;
        *) 
            echo -e "${red}[Error]${nc} Invalid option! Please select 0-6 or x."
            sleep 1
            ;;
    esac
done