#!/bin/bash
# =========================================
# Name    : system-menu
# Title   : Interactive Menu for VPS System Utilities and Configuration
# Version : 1.1 (Safety and Flow Fixes)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Main Menu Loop ---
while true; do
    clear

    # ===== SYSTEM MENU =====
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}            • SYSTEM MENU •             ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo -e " [${blue}1${nc}] Domain Panel (m-domain)"
    echo -e " [${blue}2${nc}] VPS Speedtest"
    echo -e " [${blue}3${nc}] Configure Auto Reboot (auto-reboot)"
    echo -e " [${blue}4${nc}] Restart All Services (restart)"
    echo -e " [${blue}5${nc}] Check Bandwidth Usage (cek-bw)"
    echo -e " [${blue}6${nc}] Install TCP BBR (m-tcp)"
    echo -e " [${blue}7${nc}] DNS Changer (m-dns)"
    echo ""
    echo -e " [${red}0${nc}] Back to Main Menu"
    echo -e " [x] Exit"
    echo ""
    echo -e "${red}=========================================${nc}"
    echo ""

    read -rp " Select menu : " opt
    echo ""

    case "$opt" in
        1) clear ; m-domain ;;
        2) 
            clear
            if command -v speedtest >/dev/null; then
                echo -e "${yellow}Starting VPS Speedtest...${nc}"
                speedtest
            else
                echo -e "${red}Error:${nc} The 'speedtest' command is not installed."
                echo -e "Install it via: ${yellow}apt install speedtest${nc}"
            fi
            read -n 1 -s -r -p "Press any key to return to the menu..."
            ;;
        3) clear ; auto-reboot ;;
        4) clear ; restart ;;
        5) clear ; cek-bw ;;
        6) clear ; m-tcp ;;
        7) clear ; m-dns ;;
        0) 
            clear
            # Call parent menu function if it exists, otherwise exit
            menu 2>/dev/null || exit 0
            ;;
        x|X) exit 0 ;;
        *) 
            echo -e "${red}[Error]${nc} Invalid option! Please select a number from 0-7 or x."
            sleep 1
            ;;
    esac
done