#!/bin/bash
# =========================================
# Name    : vmess-menu
# Title   : Interactive Menu for VMess Account Management
# Version : 1.1 (Safety and Flow Fixes)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

VMESS_LOG_FILE="/etc/log-create-vmess.log"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Main Menu Loop ---
while true; do
    clear

    # ===== VMESS MENU =====
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}            • VMESS MENU •          ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo -e " [${blue}1${nc}] Create VMess Account (add-ws)"
    echo -e " [${blue}2${nc}] Create Trial VMess Account (trialvmess)"
    echo -e " [${blue}3${nc}] Extend VMess Account (renew-ws)"
    echo -e " [${blue}4${nc}] Delete VMess Account (del-ws)"
    echo -e " [${blue}5${nc}] Check VMess Logins (cek-ws)"
    echo -e " [${blue}6${nc}] List Created Accounts Log"
    echo ""
    echo -e " [${red}0${nc}] Back to Main Menu"
    echo -e " [x] Exit"
    echo ""
    echo -e "${red}=========================================${nc}"
    echo -ne " Select an option: "

    read opt
    echo ""

    case "$opt" in
        1) clear ; add-ws ;;
        2) clear ; trialvmess ;;
        3) clear ; renew-ws ;;
        4) clear ; del-ws ;;
        5) clear ; cek-ws ;;
        6) 
            clear
            echo -e "${yellow}--- CREATED VMESS ACCOUNTS LOG ---${nc}"
            if [ -f "$VMESS_LOG_FILE" ]; then
                cat "$VMESS_LOG_FILE"
            else
                echo -e "${red}Error:${nc} Log file $VMESS_LOG_FILE not found."
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