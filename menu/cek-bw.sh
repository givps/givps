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

# Display menu
echo -e "${red}=========================================${nc}"
echo -e "${blue}           BANDWIDTH MONITOR                 ${nc}"
echo -e "${red}=========================================${nc}"
echo -e ""
echo -e "${blue} 1 ${nc} View Total Remaining Bandwidth"
echo -e "${blue} 2 ${nc} Usage Every 5 Minutes"
echo -e "${blue} 3 ${nc} Hourly Usage"
echo -e "${blue} 4 ${nc} Daily Usage"
echo -e "${blue} 5 ${nc} Monthly Usage"
echo -e "${blue} 6 ${nc} Yearly Usage"
echo -e "${blue} 7 ${nc} Highest Usage"
echo -e "${blue} 8 ${nc} Hourly Usage Statistics"
echo -e "${blue} 9 ${nc} View Current Active Usage"
echo -e "${blue} 10 ${nc} Live Traffic [5s Interval]"
echo -e ""
echo -e "${blue} 0 Back To Menu ${nc}"
echo -e "${blue} x Exit ${nc}"
echo -e ""
echo -e "${red}=========================================${nc}"
echo -e ""

read -p " Select menu option: " opt
echo -e ""

case $opt in
1)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}       TOTAL SERVER BANDWIDTH REMAINING       ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
2)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}       TOTAL BANDWIDTH EVERY 5 MINUTES       ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -5
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
3)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           HOURLY BANDWIDTH                  ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -h
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
4)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           DAILY BANDWIDTH                   ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -d
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
5)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           MONTHLY BANDWIDTH                 ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -m
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
6)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}           YEARLY BANDWIDTH                  ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -y
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
7)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}         HIGHEST BANDWIDTH USAGE            ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -t
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
8)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}         HOURLY USAGE STATISTICS            ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -hg
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
9)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          CURRENT LIVE BANDWIDTH            ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} Press [ Ctrl+C ] To Exit ${nc}"
    echo -e ""
    vnstat -l
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
10)
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        LIVE BANDWIDTH TRAFFIC [5s]         ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    vnstat -tr
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""
    read -n 1 -s -r -p "Press any key to return..."
    bw
    ;;
0)
    sleep 1
    m-system
    ;;
x)
    exit
    ;;
*)
    echo -e ""
    echo -e "${red} Invalid option, please try again... ${nc}"
    sleep 1
    bw
    ;;
esac
