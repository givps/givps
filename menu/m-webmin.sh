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

Info="${green}[Installed]${nc}"
Error="${red}[Not Installed]${nc}"

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

# Check if Webmin is running
cek=$(netstat -ntlp 2>/dev/null | grep ":10000" | awk '{print $7}' | cut -d'/' -f2)

# ===== Functions =====
install_webmin() {
    IP=$(wget -qO- ipv4.icanhazip.com)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          • INSTALL WEBMIN •        ${nc}"
    echo -e "${red}=========================================${nc}"
    
    echo -e "${green}[Info]${nc} Adding Webmin repository..."
    echo "deb http://download.webmin.com/download/repository sarge contrib" \
        > /etc/apt/sources.list.d/webmin.list

    apt install -y gnupg gnupg1 gnupg2 > /dev/null 2>&1
    wget -q http://www.webmin.com/jcameron-key.asc
    apt-key add jcameron-key.asc > /dev/null 2>&1
    rm -f jcameron-key.asc

    echo -e "${green}[Info]${nc} Installing Webmin..."
    apt update > /dev/null 2>&1
    apt install -y webmin > /dev/null 2>&1

    # Disable SSL (optional)
    sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf

    echo -e "${green}[Info]${nc} Restarting Webmin..."
    systemctl restart webmin

    echo -e "\n${green}[Info]${nc} Webmin installed successfully!"
    echo "Access Webmin at: http://$IP:10000"
    
    read -n 1 -s -r -p "Press any key to return to the menu..."
    m-webmin
}

restart_webmin() {
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          • RESTART WEBMIN •        ${nc}"
    echo -e "${red}=========================================${nc}"

    echo -e "${green}[Info]${nc} Restarting Webmin..."
    systemctl restart webmin > /dev/null 2>&1

    echo -e "\n${green}[Info]${nc} Webmin restarted successfully!"
    read -n 1 -s -r -p "Press any key to return to the menu..."
    m-webmin
}

uninstall_webmin() {
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        • UNINSTALL WEBMIN •       ${nc}"
    echo -e "${red}=========================================${nc}"

    echo -e "${green}[Info]${nc} Removing Webmin repository..."
    rm -f /etc/apt/sources.list.d/webmin.list
    apt update > /dev/null 2>&1

    echo -e "${green}[Info]${nc} Uninstalling Webmin..."
    apt autoremove --purge -y webmin > /dev/null 2>&1

    echo -e "\n${green}[Info]${nc} Webmin uninstalled successfully!"
    read -n 1 -s -r -p "Press any key to return to the menu..."
    m-webmin
}

# ===== Main Menu =====
if [[ "$cek" == "perl" ]]; then
    sts="$Info"
else
    sts="$Error"
fi

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
case $num in
    1) install_webmin ;;
    2) restart_webmin ;;
    3) uninstall_webmin ;;
    0) menu ;;
    x|X) exit 0 ;;
    *) echo -e "\n${red}[Error]${nc} Invalid option!" ; sleep 2 ; m-webmin ;;
esac
