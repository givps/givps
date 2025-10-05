#!/bin/bash
# =========================================
# Name    : service-status-checker
# Title   : Auto Script VPS Service Status Display
# Version : 1.1 (Logic Fixes and Robustness)
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

# --- Functions ---

# Function to check service status and return colored status string
check_service() {
  local svc="$1"
  if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    if systemctl is-active --quiet "$svc"; then
      echo -e "${green}Running${nc} (Active)"
    else
      echo -e "${yellow}Failed${nc} (Inactive/Error)"
    fi
  else
    # Check if the unit file even exists
    if systemctl list-unit-files "$svc" 2>/dev/null | grep -q "$svc"; then
        echo -e "${yellow}Disabled${nc} (Not Running)"
    else
        echo -e "${red}Not Installed${nc} (Unit Missing)"
    fi
  fi
}

# --- Data Collection ---
clear

# ========== OS INFO ==========
# Use a safer method for sourcing OS info
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=${NAME:-"Linux"}
    OS_VERSION=${VERSION_ID:-"N/A"}
else
    OS_NAME="Linux"
    OS_VERSION="N/A"
fi

# ========== VPS INFO ==========
IPVPS=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "N/A")

# ========== SERVICE STATUS ==========
# Check core services
status_ssh=$(check_service ssh)
status_dropbear=$(check_service dropbear)
status_stunnel=$(check_service stunnel4)
status_fail2ban=$(check_service fail2ban)
status_cron=$(check_service cron)
status_vnstat=$(check_service vnstat)

# Check primary VPN components
status_xray_core=$(check_service xray)
status_trojan_go=$(check_service trojan-go) # Check for trojan-go service
status_shadowsocks_libev=$(check_service shadowsocks-libev) # Check for SS service (example)

# Check WebSocket Tunneling services (as defined in previous scripts)
status_ws_tls=$(check_service ws-stunnel.service)
status_ws_dropbear=$(check_service ws-dropbear.service)

# ========== SYSTEM INFO ==========
total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "N/A")
kernel_ver=$(uname -r)
domain="$(cat /etc/xray/domain 2>/dev/null || echo '-')"

# Placeholder Variables
Name="VIP-MEMBERS"
Exp="Lifetime"

# ========== OUTPUT ==========
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}             SYSTEM INFORMATION              ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} Hostname        ${nc}: $HOSTNAME"
echo -e "${blue} OS Name         ${nc}: $OS_NAME $OS_VERSION"
echo -e "${blue} Kernel          ${nc}: $kernel_ver"
echo -e "${blue} Total RAM       ${nc}: ${total_ram} MB"
echo -e "${blue} Public IP       ${nc}: $IPVPS"
echo -e "${blue} Domain          ${nc}: $domain"
echo -e "${red}=========================================${nc}"
echo -e "${blue}          SUBSCRIPTION INFORMATION           ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} Client Name     ${nc}: $Name"
echo -e "${blue} Script Expiry   ${nc}: $Exp"
echo -e "${blue} Version         ${nc}: 1.1 (Revised)"
echo -e "${red}=========================================${nc}"
echo -e "${blue}             SERVICE STATUS LIST             ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} OpenSSH               ${nc}: $status_ssh"
echo -e "${blue} Dropbear              ${nc}: $status_dropbear"
echo -e "${blue} Stunnel4              ${nc}: $status_stunnel"
echo -e "${blue} Fail2Ban              ${nc}: $status_fail2ban"
echo -e "${blue} Cron Scheduler        ${nc}: $status_cron"
echo -e "${blue} Vnstat (Bandwidth)    ${nc}: $status_vnstat"
echo -e "${red}-----------------------------------------${nc}"
echo -e "${blue} XRAY Core (VMess/VLESS/Trojan) ${nc}: $status_xray_core"
echo -e "${blue} Trojan-Go             ${nc}: $status_trojan_go"
echo -e "${blue} Shadowsocks-Libev     ${nc}: $status_shadowsocks_libev"
echo -e "${red}-----------------------------------------${nc}"
echo -e "${blue} WebSocket Stunnel     ${nc}: $status_ws_tls"
echo -e "${blue} WebSocket Dropbear    ${nc}: $status_ws_dropbear"
echo -e "${red}=========================================${nc}"
echo -e "${blue}              t.me/givps_com             ${nc}"
echo -e "${red}=========================================${nc}"
echo ""

read -n 1 -s -r -p "Press any key to return to the menu..."

# Call parent menu function if it exists, otherwise exit
menu 2>/dev/null || exit 0