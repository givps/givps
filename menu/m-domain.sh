#!/bin/bash
# =========================================
# Name    : domain-menu
# Title   : Interactive Menu for VPS Domain and Certificate Management
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

# Detect VPS Public IP (Not strictly needed, but kept for context consistency)
# MYIP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "127.0.0.1")

# --- Main Menu Loop ---
while true; do
    clear
    
    # ===== DOMAIN MENU =====
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           • DOMAIN MENU •          ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}  • Don't Forget to RENEW CERTIFICATE •  ${nc}"
    echo -e "${blue}        • After Changing Domain •        ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    echo -e " [${blue}1${nc}] Change VPS Domain (add-host)"
    echo -e " [${blue}2${nc}] Renew Domain Certificate (xray-crt)"
    echo ""
    echo -e " [${red}0${nc}] Back to System Menu"
    echo -e " [x] Exit"
    echo ""
    echo -e "${red}=========================================${nc}"
    echo ""

    read -rp " Select an option: " opt
    echo ""

    case "$opt" in
        1) 
            clear
            echo -e "${green}Starting Domain Change...${nc}"
            # Assumes 'add-host' is in PATH
            add-host
            read -n 1 -s -r -p "Press any key to return to the menu..."
            ;;
        2) 
            clear
            echo -e "${green}Starting Certificate Renewal...${nc}"
            # Assumes 'xray-crt' is in PATH
            xray-crt
            read -n 1 -s -r -p "Press any key to return to the menu..."
            ;;
        0) 
            clear
            # Call parent menu function if it exists, otherwise exit
            m-system 2>/dev/null || exit 0
            ;;
        x|X) 
            exit 0
            ;;
        *) 
            echo -e "${red}[Error]${nc} Invalid option! Please select 0, 1, 2, or x."
            sleep 1
            ;;
    esac
done