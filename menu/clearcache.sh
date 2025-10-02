#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto VPS Script to Clear RAM Cache on Debian & Ubuntu Server
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

echo -e "[ ${green}INFO${nc} ] VPS Detected: $MYIP"
echo -e "[ ${green}INFO${nc} ] Clearing RAM Cache..."

# Execute cache clearing command (requires root)
sync
echo 3 > /proc/sys/vm/drop_caches

sleep 1
echo -e "[ ${green}OK${nc} ] RAM Cache cleared successfully"
echo ""
echo -e "[ ${green}INFO${nc} ] Returning to menu in 2 seconds..."
sleep 2

# Call main menu
menu
