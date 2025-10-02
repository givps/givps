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
logfile="/root/log-install.txt"

echo "Checking VPS..."
sleep 1
clear

if grep -qw "XRAY" $logfile; then
    domain=$(cat /etc/xray/domain)
else
    domain=$(cat /etc/v2ray/domain)
fi

# Get ports from log
port_ssh_ws=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | awk '{print $1}')
port_ssh_ws_ssl=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | awk '{print $1}')
port_openssh=$(grep -w "OpenSSH" ~/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')
port_dropbear=$(grep -w "Dropbear" ~/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')
port_ssl=$(grep -w "Stunnel4" ~/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')

# User input
echo -e "${red}=========================================${nc}"
echo -e "${blue}            SSH ACCOUNT            ${nc}"
echo -e "${red}=========================================${nc}"
read -p "Username (Input/Enter = random): " Login
read -p "Password (Input/Enter = random): " Pass
read -p "Active Days (Input/Enter = 30): " expdays

# Defaults if empty
if [[ -z "$Login" ]]; then
    Login="user$(shuf -i 1000-9999 -n 1)"
    echo -e "Auto-generated Username: ${green}$Login${nc}"
fi

if [[ -z "$Pass" ]]; then
    Pass=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8)
    echo -e "Auto-generated Password: ${green}$Pass${nc}"
fi

if [[ -z "$expdays" ]]; then
    expdays=30
    echo -e "Default Expiration: ${green}$expdays days${nc}"
fi

# Check if user already exists
if id "$Login" &>/dev/null; then
    echo -e "${red}Error:${NC} User $Login already exists!"
    exit 1
fi

# Create user
useradd -e $(date -d "$expdays days" +"%Y-%m-%d") -s /bin/false -M $Login
echo -e "$Pass\n$Pass\n" | passwd $Login &>/dev/null
expdate=$(chage -l $Login | grep "Account expires" | awk -F": " '{print $2}')
IP=$(curl -sS ipv4.icanhazip.com)

# Save to log file
{
    echo -e "\n================ SSH ACCOUNT ================\n"
    {
        echo "Username      : $Login"
        echo "Password      : $Pass"
        echo "Expired On    : $expdate"
        echo "IP Address    : $IP"
        echo "Host/Domain   : $domain"
        echo "OpenSSH       : $port_openssh"
        echo "Dropbear      : $port_dropbear"
        echo "SSH WS        : $port_ssh_ws"
        echo "SSH SSL WS    : $port_ssh_ws_ssl"
        echo "Stunnel4      : $port_ssl"
        echo "UDPGW         : 7100-7900"
    } | column -t -s ":"
    
    echo -e "\n================ PAYLOADS ==================\n"
    echo "WebSocket Payload (WSS)"
    echo "GET wss://bug.com HTTP/1.1[crlf]Host: ${domain}[crlf]Upgrade: websocket[crlf][crlf]"
    echo
    echo "WebSocket Payload (WS)"
    echo "GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
    echo -e "\n============================================\n"
} | tee -a /etc/log-create-ssh.log

echo "" | tee -a /etc/log-create-ssh.log
read -n 1 -s -r -p "Press any key to return to menu..."
m-sshovpn
