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

# Function: Lock User
lock_user() {
    read -p "Enter username to LOCK: " username
    if id "$username" &>/dev/null; then
        passwd -l "$username" &>/dev/null
        clear
        echo -e " "
        echo -e "${red}=========================================${nc}"
        echo -e " Username : ${blue}$username${nc}"
        echo -e " Status   : ${red}LOCKED${nc}"
        echo -e "-----------------------------------------------"
        echo -e " Login access for user ${blue}$username${nc} has been disabled."
        echo -e "${red}=========================================${nc}"
    else
        echo -e " "
        echo -e "${red}Error:${nc} Username '${yellow}$username${nc}' not found on this server!"
        echo -e " "
    fi
}

# Function: Unlock User
unlock_user() {
    read -p "Enter username to UNLOCK: " username
    if id "$username" &>/dev/null; then
        passwd -u "$username" &>/dev/null
        clear
        echo -e " "
        echo -e "${red}=========================================${nc}"
        echo -e " Username : ${blue}$username${nc}"
        echo -e " Status   : ${green}UNLOCKED${nc}"
        echo -e "-----------------------------------------------"
        echo -e " Login access for user ${blue}$username${nc} has been restored."
        echo -e "${red}=========================================${nc}"
    else
        echo -e " "
        echo -e "${red}Error:${nc} Username '${yellow}$username${nc}' not found on this server!"
        echo -e " "
    fi
}

# Function: List All Users
list_all_users() {
    echo -e " "
    echo -e "=========== ${yellow}ALL USERS${nc} ==========="
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
    echo -e "${red}=========================================${nc}"
}

# Function: List Locked Users
list_locked_users() {
    echo -e " "
    echo -e "=========== ${red}LOCKED USERS${nc} ==========="
    passwd -S -a | awk '$2=="L" {print $1}'
    echo -e "${red}=========================================${nc}"
}

# Function: List Active Users
list_active_users() {
    echo -e " "
    echo -e "========== ${green}ACTIVE USERS${nc} ==========="
    passwd -S -a | awk '$2=="P" {print $1}'
    echo -e "${red}=========================================${nc}"
}

# Menu
while true; do
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "     ${blue}SSH USER MANAGEMENT MENU${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e " 1) Lock User"
    echo -e " 2) Unlock User"
    echo -e " 3) List All Users"
    echo -e " 4) List Locked Users"
    echo -e " 5) List Active Users"
    echo -e " 0) Back To Menu"
    echo -e ""
    echo -e   "Press x or [ Ctrl+C ] to exit"
    echo -e "${red}=========================================${nc}"
    read -p "Choose an option [0-5]: " option
    echo -e " "

    case $option in
        1) lock_user ;;
        2) unlock_user ;;
        3) list_all_users ;;
        4) list_locked_users ;;
        5) list_active_users ;;
        0) clear ; exit ; m-sshovpn ;;
        x) exit ;;
        *) echo -e "${red}Invalid option!${nc}" ;;
    esac

    echo -e ""
    read -n 1 -s -r -p "Press any key to return to the menu..."
done
