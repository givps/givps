#!/bin/bash
# =========================================
# Name    : webmin-menu
# Title   : Interactive Menu for Webmin Management
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

Info="${green}[Installed]${nc}"
Error="${red}[Not Installed]${nc}"

# --- Global IP and Status Function ---

# Function to check Webmin status
get_webmin_status() {
    # Check if 'ss' (preferred over netstat) or 'netstat' is available
    local net_cmd
    if command -v ss >/dev/null; then
        net_cmd="ss -ntlp"
    elif command -v netstat >/dev/null; then
        net_cmd="netstat -ntlp"
    else
        echo -e "${red}ERROR:${nc} Neither 'ss' nor 'netstat' found. Cannot determine status." >&2
        return 1
    fi
    
    # Check if Webmin (port 10000) is listening
    if $net_cmd 2>/dev/null | grep -q ":10000"; then
        echo "$Info"
    else
        echo "$Error"
    fi
}

# Function to get Public IP
get_public_ip() {
    wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "127.0.0.1"
}


# ===== Functions =====
install_webmin() {
    local IP=$(get_public_ip)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          • INSTALL WEBMIN •        ${nc}"
    echo -e "${red}=========================================${nc}"
    
    # Check if already installed
    if dpkg -l webmin 2>/dev/null | grep -q "^ii"; then
        echo -e "${yellow}[Warning]${nc} Webmin appears to be already installed. Exiting installation."
        return
    fi

    echo -e "${green}[Info]${nc} Adding Webmin repository..."
    if ! echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list; then
        echo -e "${red}[Error]${nc} Failed to write repository file."
        return
    fi

    echo -e "${green}[Info]${nc} Adding GPG key..."
    apt install -y gnupg gnupg1 gnupg2 > /dev/null 2>&1
    if ! wget -q http://www.webmin.com/jcameron-key.asc; then
        echo -e "${red}[Error]${nc} Failed to download GPG key."
        return
    fi
    apt-key add jcameron-key.asc > /dev/null 2>&1
    rm -f jcameron-key.asc

    echo -e "${green}[Info]${nc} Installing Webmin (This may take a moment)..."
    apt update > /dev/null 2>&1
    if ! apt install -y webmin; then
        echo -e "${red}[Error]${nc} Webmin installation failed. Check network and repository."
        return
    fi

    # Disable SSL (optional, but requested by original script)
    sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf 2>/dev/null || true

    echo -e "${green}[Info]${nc} Restarting Webmin..."
    systemctl restart webmin 2>/dev/null || true

    echo -e "\n${green}[Info]${nc} Webmin installed successfully!"
    echo "Access Webmin at: ${yellow}http://$IP:10000${nc}"
}

restart_webmin() {
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          • RESTART WEBMIN •        ${nc}"
    echo -e "${red}=========================================${nc}"

    if systemctl is-active --quiet webmin; then
        echo -e "${green}[Info]${nc} Restarting Webmin..."
        systemctl restart webmin 2>/dev/null
        echo -e "\n${green}[Info]${nc} Webmin restarted successfully!"
    else
        echo -e "${yellow}[Warning]${nc} Webmin service is not running or not installed."
    fi
}

uninstall_webmin() {
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        • UNINSTALL WEBMIN •       ${nc}"
    echo -e "${red}=========================================${nc}"

    read -rp "Are you sure you want to uninstall Webmin? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo -e "\n${yellow}[Info]${nc} Uninstallation cancelled."
        return
    fi

    echo -e "${green}[Info]${nc} Removing Webmin repository file..."
    rm -f /etc/apt/sources.list.d/webmin.list
    apt update > /dev/null 2>&1

    echo -e "${green}[Info]${nc} Uninstalling Webmin..."
    if apt autoremove --purge -y webmin; then
        echo -e "\n${green}[Info]${nc} Webmin uninstalled successfully!"
    else
        echo -e "\n${red}[Error]${nc} Webmin removal failed. It may not have been fully installed."
    fi
}

# ===== Main Menu Loop =====
while true; do
    
    sts=$(get_webmin_status)
    
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           • WEBMIN MENU •          ${nc}"
    echo -e "${red}=========================================${nc}"

    echo -e " Status : $sts"
    echo -e " [${blue}1${nc}] Install Webmin"
    echo -e " [${blue}2${nc}] Restart Webmin"
    echo -e " [${blue}3${nc}] Uninstall Webmin"
    echo -e ""
    echo -e " [${red}0${nc}] Back to Main Menu"
    echo -e " [x] Exit"
    echo -e "${red}=========================================${nc}"

    read -rp " Select an option [0-3 or x]: " num
    echo ""
    
    case "$num" in
        1) install_webmin ;;
        2) restart_webmin ;;
        3) uninstall_webmin ;;
        0) 
            # Call parent menu function if it exists, otherwise exit
            menu 2>/dev/null || exit 0
            ;;
        x|X) exit 0 ;;
        *) echo -e "\n${red}[Error]${nc} Invalid option!" ; sleep 2 ;;
    esac
    
    # Pause for user feedback, unless exiting
    if [[ "$num" != "0" && "$num" != "x" ]]; then
        read -n 1 -s -r -p "Press any key to return to the menu..."
    fi
done