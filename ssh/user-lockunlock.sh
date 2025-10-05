#!/bin/bash
# =========================================
# Name    : user-management-menu
# Title   : Auto Script VPS to Manage SSH User Status
# Version : 1.1 (Consistency and Robustness Refinement)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Exit immediately if a command exits with a non-zero status
# Exit if any pipeline fails. Treat unset variables as an error.
set -eo pipefail

# Detect VPS Public IP (Not used, but kept for context)
MYIP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "127.0.0.1")
clear

# --- Helper Function for Filtering Non-System Users ---
# Filters users with UID >= 1000 and excludes 'nobody'
filter_users() {
    # Use -a to check all users, then filter by status and UID
    passwd -S -a 2>/dev/null | awk -v MIN_UID=1000 '
        BEGIN {
            FS=" "; 
            OFS=" ";
        }
        {
            user=$1;
            status=$2;
        }
        # Check UID against /etc/passwd only if the user status check passed
        ("'"$(id -u "$user" 2>/dev/null)"'") >= MIN_UID && user != "nobody" {
            print $0
        }
    '
}

# Function: Lock User
lock_user() {
    read -rp "Enter username to LOCK: " username
    if id "$username" &>/dev/null; then
        # Check if user is a system user (UID < 1000). Prevent locking critical accounts.
        if [[ "$(id -u "$username")" -lt 1000 ]]; then
            echo -e "\n${red}Error:${nc} Cannot lock system account '${yellow}$username${nc}' (UID < 1000)."
            return
        fi

        passwd -l "$username" &>/dev/null
        clear
        echo -e "\n${red}=========================================${nc}"
        echo -e " Username : ${blue}$username${nc}"
        echo -e " Status   : ${red}LOCKED${nc}"
        echo -e "-----------------------------------------------"
        echo -e " Login access for user ${blue}$username${nc} has been disabled."
        echo -e "${red}=========================================${nc}"
    else
        echo -e "\n${red}Error:${nc} Username '${yellow}$username${nc}' not found on this server!"
    fi
}

# Function: Unlock User
unlock_user() {
    read -rp "Enter username to UNLOCK: " username
    if id "$username" &>/dev/null; then
        passwd -u "$username" &>/dev/null
        clear
        echo -e "\n${red}=========================================${nc}"
        echo -e " Username : ${blue}$username${nc}"
        echo -e " Status   : ${green}UNLOCKED${nc}"
        echo -e "-----------------------------------------------"
        echo -e " Login access for user ${blue}$username${nc} has been restored."
        echo -e "${red}=========================================${nc}"
    else
        echo -e "\n${red}Error:${nc} Username '${yellow}$username${nc}' not found on this server!"
    fi
}

# Function: List All Users (Non-system)
list_all_users() {
    echo -e "\n=========== ${yellow}ALL NON-SYSTEM USERS${nc} ==========="
    # List all users with UID >= 1000, excluding 'nobody'
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | sort
    echo -e "${red}=========================================${nc}"
}

# Function: List Locked Users
list_locked_users() {
    echo -e "\n=========== ${red}LOCKED USERS${nc} ==========="
    # Filter users: Get all users, then print only those whose passwd -S output shows 'L' (Locked)
    filter_users | awk '$2=="L" {print $1}' | sort
    echo -e "${red}=========================================${nc}"
}

# Function: List Active Users (Accounts that can log in - not locked)
list_active_users() {
    echo -e "\n========== ${green}LOGGABLE USERS${nc} ==========="
    # Filter users: Print users whose status is not 'L' (Locked)
    filter_users | awk '$2!="L" {print $1}' | sort
    echo -e "${red}=========================================${nc}"
}

# --- Main Menu Loop ---
while true; do
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "     ${blue}SSH USER MANAGEMENT MENU${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e " 1) Lock User"
    echo -e " 2) Unlock User"
    echo -e " 3) List All Users"
    echo -e " 4) List Locked Users"
    echo -e " 5) List Loggable Users (Not Locked)"
    echo -e " 0) Back To Main Menu"
    echo -e ""
    echo -e   "Press x or [ Ctrl+C ] to exit"
    echo -e "${red}=========================================${nc}"
    read -rp "Choose an option [0-5]: " option
    echo -e " "

    case "$option" in
        1) lock_user ;;
        2) unlock_user ;;
        3) list_all_users ;;
        4) list_locked_users ;;
        5) list_active_users ;; # Renamed output for clarity
        0) clear ; m-sshovpn 2>/dev/null || exit 0 ;;
        x) exit 0 ;;
        *) echo -e "${red}Invalid option!${nc}" ;;
    esac

    echo -e ""
    read -n 1 -s -r -p "Press any key to return to the menu..."
done