#!/bin/bash
# =========================================
# Name    : bw-monitor-menu
# Title   : Interactive Menu for Bandwidth Monitoring (vnstat wrapper)
# Version : 1.1 (Robustness and Flow Fixes)
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

# --- Pre-check: Ensure vnstat is installed ---
if ! command -v vnstat &> /dev/null; then
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${red}ERROR: vnstat is not installed!${nc}"
    echo -e "Please install it using: ${yellow}apt install vnstat -y${nc}"
    echo -e "========================================="
    exit 1
fi

# Function to run vnstat and display output
run_vnstat() {
    local title="$1"
    local command="$2"
    
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}      $title       ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    
    # Check for live traffic options which require specific handling for user exit
    if [[ "$command" == "vnstat -l" || "$command" == "vnstat -tr" ]]; then
        echo -e "${yellow} Press [ Ctrl+C ] To Stop Monitoring ${nc}"
        echo -e ""
    fi
    
    # Execute the command
    eval "$command"
    
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
}

# --- Main Menu Loop ---
while true; do
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           BANDWIDTH MONITOR MENU          ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    echo -e "${blue} 1 ${nc} View Total Remaining Bandwidth"
    echo -e "${blue} 2 ${nc} Usage Every 5 Minutes"
    echo -e "${blue} 3 ${nc} Hourly Usage"
    echo -e "${blue} 4 ${nc} Daily Usage"
    echo -e "${blue} 5 ${nc} Monthly Usage"
    echo -e "${blue} 6 ${nc} Yearly Usage"
    echo -e "${blue} 7 ${nc} Highest Usage Records"
    echo -e "${blue} 8 ${nc} Hourly Usage Statistics (Graph)"
    echo -e "${blue} 9 ${nc} View Current Active Usage (Live)"
    echo -e "${blue} 10 ${nc} Live Traffic [5s Interval]"
    echo -e ""
    echo -e "${blue} 0 ${nc} Back To Menu"
    echo -e "${blue} x ${nc} Exit"
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""

    read -rp " Select menu option: " opt
    echo -e ""

    case "$opt" in
        1)
            run_vnstat "TOTAL SERVER BANDWIDTH" "vnstat"
            ;;
        2)
            run_vnstat "BANDWIDTH EVERY 5 MINUTES" "vnstat -5"
            ;;
        3)
            run_vnstat "HOURLY BANDWIDTH" "vnstat -h"
            ;;
        4)
            run_vnstat "DAILY BANDWIDTH" "vnstat -d"
            ;;
        5)
            run_vnstat "MONTHLY BANDWIDTH" "vnstat -m"
            ;;
        6)
            run_vnstat "YEARLY BANDWIDTH" "vnstat -y"
            ;;
        7)
            run_vnstat "HIGHEST BANDWIDTH USAGE" "vnstat -t"
            ;;
        8)
            run_vnstat "HOURLY USAGE STATISTICS" "vnstat -hg"
            ;;
        9)
            run_vnstat "CURRENT LIVE BANDWIDTH" "vnstat -l"
            ;;
        10)
            run_vnstat "LIVE BANDWIDTH TRAFFIC [5s]" "vnstat -tr"
            ;;
        0)
            # Call parent menu function if it exists, otherwise exit
            m-system 2>/dev/null || exit 0
            ;;
        x)
            exit 0
            ;;
        *)
            echo -e "${red} Invalid option, please try again... ${nc}"
            sleep 1
            continue # Restart the loop/menu
            ;;
    esac

    # Pause after execution, but only if not exiting the script
    if [[ "$opt" != "0" && "$opt" != "x" ]]; then
        read -n 1 -s -r -p "Press any key to return to the menu..."
    fi
done