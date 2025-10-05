#!/bin/bash
# =========================================
# Name    : create-ssh-user
# Title   : Auto Script VPS to Create VPN/SSH User
# Version : 1.1 (Robustness and Security Refinement)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Exit immediately if a command exits with a non-zero status
set -eo pipefail

# --- Configuration ---
INSTALL_LOG_FILE="/root/log-install.txt"
CREATE_LOG_FILE="/var/log/ssh-user-creates.log"

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

echo "Checking VPS..."
sleep 0.5
clear

# --- 1. Detect Domain/IP ---
# Safely check for domain and fallback to IP if files are missing/empty.
DOMAIN=""
if [ -f "/etc/xray/domain" ]; then
    DOMAIN=$(cat /etc/xray/domain)
elif [ -f "/etc/v2ray/domain" ]; then
    DOMAIN=$(cat /etc/v2ray/domain)
fi

# Fallback to VPS IP if domain is not found
if [[ -z "$DOMAIN" ]]; then
    DOMAIN="$MYIP"
fi

# --- 2. Get Ports from Log ---
# Use safer methods and fallbacks for grep/cut operations
get_port() {
    local pattern="$1"
    local fallback="$2"
    # Search the log file, cut, awk, and return the first part or the fallback
    grep -w "$pattern" "$INSTALL_LOG_FILE" 2>/dev/null | cut -d: -f2 | awk '{print $1,$2}' | xargs || echo "$fallback"
}

PORT_SSH_WS=$(get_port "noneTLS" "-")
PORT_SSH_WS_SSL=$(get_port "TLS" "-")
PORT_OPENSSH=$(get_port "OpenSSH" "22")
PORT_DROPBEAR=$(get_port "Dropbear" "109")
PORT_SSL=$(get_port "Stunnel4" "444")

# --- 3. User Input and Defaults ---
echo -e "${red}=========================================${nc}"
echo -e "${blue}            SSH ACCOUNT CREATOR            ${nc}"
echo -e "${red}=========================================${nc}"
read -rp "Username (Input/Enter = random 4-digit): " Login
read -rp "Password (Input/Enter = random 8-char): " Pass
read -rp "Active Days (Input/Enter = 30): " expdays

# Set Defaults
if [[ -z "$Login" ]]; then
    # Generate 4-digit random username
    Login="user$(head /dev/urandom | tr -dc 0-9 | head -c4)"
    echo -e "Auto-generated Username: ${green}$Login${nc}"
fi

if [[ -z "$Pass" ]]; then
    # Generate 8-character secure random password
    Pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c8)
    echo -e "Auto-generated Password: ${green}$Pass${nc}"
fi

if [[ -z "$expdays" ]]; then
    expdays=30
    echo -e "Default Expiration: ${green}$expdays days${nc}"
fi

# --- 4. Validation ---
# Check if user already exists
if id "$Login" &>/dev/null; then
    echo -e "${red}Error:${nc} User '$Login' already exists! Aborting."
    exit 1
fi

# Check if days input is a positive integer
if ! [[ "$expdays" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${red}Error:${nc} Invalid expiration days specified. Aborting."
    exit 1
fi

# --- 5. Create User ---
EXP_DATE_FORMATTED=$(date -d "$expdays days" +"%Y-%m-%d")

# Create user with no home directory (-M) and no shell (-s /bin/false)
useradd -e "$EXP_DATE_FORMATTED" -s /bin/false -M "$Login"
echo -e "$Pass\n$Pass\n" | passwd "$Login" &>/dev/null

# Get human-readable expiration date for display
EXP_DATE_DISPLAY=$(chage -l "$Login" | grep "Account expires" | awk -F": " '{print $2}')

# --- 6. Output and Logging ---
{
    echo -e "\n=============================================="
    echo -e "$(date +"%Y-%m-%d %H:%M:%S") - SSH ACCOUNT CREATED"
    echo -e "=============================================="
    echo "Username      : $Login"
    echo "Password      : $Pass"
    echo "Expired On    : $EXP_DATE_DISPLAY (Date: $EXP_DATE_FORMATTED)"
    echo "IP Address    : $MYIP"
    echo "Host/Domain   : $DOMAIN"
    echo "OpenSSH       : $PORT_OPENSSH"
    echo "Dropbear      : $PORT_DROPBEAR"
    echo "Stunnel4      : $PORT_SSL"
    echo "SSH WS        : $PORT_SSH_WS (No TLS)"
    echo "SSH SSL WS    : $PORT_SSH_WS_SSL (TLS)"
    echo "UDPGW         : 7100-7900 (Proxy)"
    echo -e "\n================ PAYLOADS ===================="
    echo -e "${blue}WebSocket Payload (WSS - Secure)${nc}"
    echo "GET wss://bug.com HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]"
    echo
    echo -e "${blue}WebSocket Payload (WS - Non-Secure)${nc}"
    echo "GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]"
    echo -e "=============================================="
} | tee -a "$CREATE_LOG_FILE"

echo ""
read -n 1 -s -r -p "Press any key to return to menu..."
# Execute the presumed main menu function, suppressing errors if it doesn't exist
m-sshovpn 2>/dev/null || exit 0