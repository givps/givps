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

dnsfile="/root/dns"

# Header
echo -e "${red}=========================================${nc}"
echo -e "${blue}              DNS CHANGER${nc}"
echo -e "${red}=========================================${nc}"

# Check active DNS
if [[ -f "$dnsfile" ]]; then
    udns=$(cat "$dnsfile")
    echo -e "\n Active DNS : ${blue}$udns${nc}"
fi

echo -e ""
echo -e " [${blue}1${nc}] Change DNS (example: 1.1.1.1)"
echo -e " [${blue}2${nc}] Reset DNS to Google (8.8.8.8)"
echo -e " [${blue}3${nc}] Reboot after updating DNS"
echo -e ""
echo -e " [${red}0${nc}] Back To System Menu"
echo -e " [x] Exit"
echo -e ""
echo -e "${red}=========================================${nc}"
echo -e ""

read -rp " Select option [0-3]: " dns
echo ""

case $dns in
1)
    clear
    read -rp " Please enter DNS (IP only): " dns1
    if [[ -z "$dns1" ]]; then
        echo -e "${red}Error:${nc} DNS cannot be empty!"
        sleep 2
        exec "$0"
    fi

    rm -f /etc/resolv.conf /etc/resolvconf/resolv.conf.d/head
    echo "$dns1" > "$dnsfile"

    echo "nameserver $dns1" > /etc/resolv.conf
    echo "nameserver $dns1" > /etc/resolvconf/resolv.conf.d/head

    systemctl restart resolvconf.service 2>/dev/null

    echo -e "\n${green}Success:${nc} DNS $dns1 applied to VPS"
    cat /etc/resolvconf/resolv.conf.d/head
    sleep 2
    exec "$0"
    ;;
2)
    clear
    read -rp " Reset to Google DNS (8.8.8.8)? [y/N]: " answer
    case "$answer" in
        y|Y)
            rm -f "$dnsfile"
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
            echo -e "\n${green}INFO:${nc} DNS reset to Google (8.8.8.8)"
            sleep 2
            ;;
        n|N|*)
            echo -e "\n${yellow}INFO:${nc} Operation cancelled by user."
            sleep 2
            ;;
    esac
    exec "$0"
    ;;
3)
    clear
    echo -e "${green}INFO:${nc} Rebooting system..."
    sleep 2
    reboot
    ;;
0)
    clear
    m-system
    ;;
x|X)
    exit 0
    ;;
*)
    echo -e "${red}Error:${nc} Invalid option!"
    sleep 2
    exec "$0"
    ;;
esac
