#!/bin/bash
# =========================================
# Name    : install-ssh-ws
# Title   : Install WebSocket Services for SSH (Dropbear & Stunnel)
# Version : 1.1 (Revised for Robustness)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # Reset color

# --- Configuration ---
# NOTE: These are standard ports. Adjust if your SSH/Dropbear/Stunnel uses different ports.
WS_DB_PORT="8880"   # Port where ws-dropbear will listen (e.g., WS over HTTP)
WS_ST_PORT="8443"   # Port where ws-stunnel will listen (e.g., WS over TLS)

clear
echo -e "${green}Checking VPS...${nc}"
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}IP Detected: $MYIP${nc}"
cd

# --- Pre-requisite Check: Python ---
echo -e "${green}==> Checking and installing Python3...${nc}"
if ! command -v python3 &> /dev/null; then
  apt update && apt install -y python3 python3-pip || { echo -e "${red}❌ Failed to install python3!${nc}"; exit 1; }
fi
echo -e "${green}Python3 is installed.${nc}"

echo -e "${green}==> Installing Websocket-SSH Python services...${nc}"

# --- Download Python WebSocket scripts ---
BASE_URL="https://raw.githubusercontent.com/givps/givps/master/sshws"

echo -e "${green}[1/4] Downloading ws-dropbear...${nc}"
wget -q --no-check-certificate -O /usr/local/bin/ws-dropbear "$BASE_URL/ws-dropbear" \
  || { echo -e "${red}❌ Failed to download ws-dropbear!${nc}"; exit 1; }

echo -e "${green}[2/4] Downloading ws-stunnel...${nc}"
wget -q --no-check-certificate -O /usr/local/bin/ws-stunnel "$BASE_URL/ws-stunnel" \
  || { echo -e "${red}❌ Failed to download ws-stunnel!${nc}"; exit 1; }

# Set executable permission
chmod +x /usr/local/bin/ws-dropbear
chmod +x /usr/local/bin/ws-stunnel

# --- Modify scripts to use defined ports (Assuming the scripts take a port argument) ---
# NOTE: We assume the scripts are meant to listen on these ports, but the original script does not show
# how the ports are configured. This is a common required step.
# If the original scripts use different internal mechanisms, this step should be adjusted.
echo -e "${green}Adjusting WebSocket scripts to listen on ports $WS_DB_PORT and $WS_ST_PORT...${nc}"
sed -i "s/8880/$WS_DB_PORT/g" /usr/local/bin/ws-dropbear 2>/dev/null
sed -i "s/8443/$WS_ST_PORT/g" /usr/local/bin/ws-stunnel 2>/dev/null

# --- Download systemd service files ---
echo -e "${green}[3/4] Setting up systemd service for ws-dropbear...${nc}"
wget -q --no-check-certificate -O /etc/systemd/system/ws-dropbear.service "$BASE_URL/ws-dropbear.service" \
  || { echo -e "${red}❌ Failed to download ws-dropbear.service!${nc}"; exit 1; }

echo -e "${green}[4/4] Setting up systemd service for ws-stunnel...${nc}"
wget -q --no-check-certificate -O /etc/systemd/system/ws-stunnel.service "$BASE_URL/ws-stunnel.service" \
  || { echo -e "${red}❌ Failed to download ws-stunnel.service!${nc}"; exit 1; }

# --- Ensure systemd services execute Python correctly ---
# Assuming the services are configured to run like: ExecStart=/usr/bin/python3 /usr/local/bin/ws-dropbear
# If they use just 'python', they should be manually checked or updated.
sed -i 's/python/python3/g' /etc/systemd/system/ws-dropbear.service 2>/dev/null
sed -i 's/python/python3/g' /etc/systemd/system/ws-stunnel.service 2>/dev/null


# --- Reload systemd and Manage services ---
echo -e "${green}Reloading systemd daemon...${nc}"
systemctl daemon-reload

echo -e "${green}Enabling and starting ws-dropbear service...${nc}"
systemctl enable ws-dropbear.service
systemctl restart ws-dropbear.service

echo -e "${green}Enabling and starting ws-stunnel service...${nc}"
systemctl enable ws-stunnel.service
systemctl restart ws-stunnel.service

clear
echo -e "${green}==> Installation completed!${nc}"
echo ""
echo -e "${green}================ Service Status ================${nc}"

echo -e "${blue}--- Dropbear WebSocket ($WS_DB_PORT) ---${nc}"
systemctl status ws-dropbear.service | grep -E 'Active:|Loaded:'

echo -e "\n${blue}--- Stunnel WebSocket ($WS_ST_PORT) ---${nc}"
systemctl status ws-stunnel.service | grep -E 'Active:|Loaded:'

echo ""
echo -e "${green}=== Last 10 logs (Dropbear WebSocket) ===${nc}"
journalctl -u ws-dropbear.service -n 10 --no-pager

echo ""
echo -e "${green}=== Last 10 logs (Stunnel WebSocket) ===${nc}"
journalctl -u ws-stunnel.service -n 10 --no-pager
echo -e "${green}==============================================${nc}"

echo -e "\n${yellow}WebSocket services should now be running on port $WS_DB_PORT (HTTP) and $WS_ST_PORT (TLS).${nc}"
echo -e "${green}Continue in 5s...${nc}"
sleep 5
clear