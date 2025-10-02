#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto VPS Script to Update Menu and Clear RAM Cache on Debian & Ubuntu Server
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
cd

# Remove old files
rm -f debian.sh
rm -f /usr/bin/clearcache
rm -f /usr/bin/menu

# Update info
echo -e "${blue}Updating menu...${nc}"
sleep 1

# Download latest files
wget -q -O /usr/bin/clearcache "https://raw.githubusercontent.com/givps/givps/master/menu/clearcache.sh"
wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/givps/givps/master/menu/menu.sh"

# Set execution permissions
chmod +x /usr/bin/clearcache
chmod +x /usr/bin/menu

# Remove leftover files
rm -f debian.sh

# Reboot info
echo -e "${blue}Auto rebooting in 5 seconds...${nc}"
sleep 5
reboot
