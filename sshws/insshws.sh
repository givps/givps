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
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # Reset color

# Detect VPS IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear
cd

echo -e "${green}==> Installing Websocket-SSH Python services...${nc}"

# Download Python WebSocket scripts
echo -e "${green}[1/4] Downloading ws-dropbear...${nc}"
wget -q -O /usr/local/bin/ws-dropbear https://raw.githubusercontent.com/givps/givps/master/sshws/ws-dropbear \
  || { echo -e "${BRed}Failed to download ws-dropbear${nc}"; exit 1; }

echo -e "${green}[2/4] Downloading ws-stunnel...${nc}"
wget -q -O /usr/local/bin/ws-stunnel https://raw.githubusercontent.com/givps/givps/master/sshws/ws-stunnel \
  || { echo -e "${BRed}Failed to download ws-stunnel${nc}"; exit 1; }

# Set executable permission
chmod +x /usr/local/bin/ws-dropbear
chmod +x /usr/local/bin/ws-stunnel

# Download systemd service files
echo -e "${green}[3/4] Setting up systemd service for ws-dropbear...${nc}"
wget -q -O /etc/systemd/system/ws-dropbear.service https://raw.githubusercontent.com/givps/givps/master/sshws/ws-dropbear.service \
  || { echo -e "${BRed}Failed to download ws-dropbear.service${nc}"; exit 1; }

echo -e "${green}[4/4] Setting up systemd service for ws-stunnel...${nc}"
wget -q -O /etc/systemd/system/ws-stunnel.service https://raw.githubusercontent.com/givps/givps/master/sshws/ws-stunnel.service \
  || { echo -e "${BRed}Failed to download ws-stunnel.service${nc}"; exit 1; }

# Reload systemd
systemctl daemon-reload

# Enable & Restart services
systemctl daemon-reload
systemctl enable ws-dropbear
systemctl restart ws-dropbear
systemctl status ws-dropbear
systemctl enable ws-dropbear.service
systemctl restart ws-dropbear.service

systemctl daemon-reload
systemctl enable ws-stunnel
systemctl restart ws-stunnel
systemctl status ws-stunnel
systemctl enable ws-stunnel.service
systemctl restart ws-stunnel.service
clear
echo -e "${green}==> Installation completed!${nc}"
echo ""
echo -e "${green}=== Service Status ===${nc}"

systemctl --no-pager status ws-dropbear.service | sed -n '1,5p'
systemctl --no-pager status ws-stunnel.service | sed -n '1,5p'

echo ""
echo -e "${green}=== Last 10 logs (Dropbear WebSocket) ===${nc}"
journalctl -u ws-dropbear.service -n 10 --no-pager

echo ""
echo -e "${green}=== Last 10 logs (Stunnel WebSocket) ===${nc}"
journalctl -u ws-stunnel.service -n 10 --no-pager
echo -e "${green}=== Continue in 5s ===${nc}"
sleep 5
clear