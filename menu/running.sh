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

# Shortcuts
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red()   { echo -e "\\033[31;1m${*}\\033[0m"; }

clear

# ========== OS INFO ==========
source /etc/os-release
OS_NAME=$NAME
OS_VERSION=$VERSION_ID

# ========== VPS INFO ==========
IPVPS=$(curl -s ipv4.icanhazip.com)

# ========== SYSTEMD SERVICE CHECKER ==========
check_service() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    echo -e "${blue}Running${nc} (No Error)"
  else
    echo -e "${red}Not Running${nc} (Error)"
  fi
}

# ========== SERVICE STATUS ==========
status_ssh=$(check_service ssh)
status_dropbear=$(check_service dropbear)
status_stunnel=$(check_service stunnel4)
status_fail2ban=$(check_service fail2ban)
status_cron=$(check_service cron)
status_vnstat=$(check_service vnstat)
status_tls_v2ray=$(check_service xray)
status_nontls_v2ray=$(check_service xray)
status_tls_vless=$(check_service xray)
status_nontls_vless=$(check_service xray)
status_trojan=$(check_service xray)
status_shadowsocks=$(check_service xray)
swstls=$(check_service ws-stunnel.service)
swsdrop=$(check_service ws-dropbear.service)

# ========== SYSTEM INFO ==========
total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
kernel_ver=$(uname -r)
domain="$(cat /etc/xray/domain 2>/dev/null || echo '-')"

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
echo -e "${blue} Version         ${nc}: 1.0"
echo -e "${red}=========================================${nc}"
echo -e "${blue}             SERVICE INFORMATION             ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} SSH / TUN             ${nc}: $status_ssh"
echo -e "${blue} Dropbear              ${nc}: $status_dropbear"
echo -e "${blue} Stunnel4              ${nc}: $status_stunnel"
echo -e "${blue} Fail2Ban              ${nc}: $status_fail2ban"
echo -e "${blue} Cron                  ${nc}: $status_cron"
echo -e "${blue} Vnstat                ${nc}: $status_vnstat"
echo -e "${blue} XRAY Vmess TLS        ${nc}: $status_tls_v2ray"
echo -e "${blue} XRAY Vmess None TLS   ${nc}: $status_nontls_v2ray"
echo -e "${blue} XRAY Vless TLS        ${nc}: $status_tls_vless"
echo -e "${blue} XRAY Vless None TLS   ${nc}: $status_nontls_vless"
echo -e "${blue} XRAY Trojan           ${nc}: $status_trojan"
echo -e "${blue} Shadowsocks           ${nc}: $status_shadowsocks"
echo -e "${blue} WebSocket TLS         ${nc}: $swstls"
echo -e "${blue} WebSocket Dropbear    ${nc}: $swsdrop"
echo -e "${red}=========================================${nc}"
echo -e "${blue}              t.me/givps_com                ${nc}"
echo -e "${red}=========================================${nc}"
echo ""

read -n 1 -s -r -p "Press any key to return to the menu..."
menu
