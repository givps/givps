#!/bin/bash
# =========================================
# Name    : create-trial
# Title   : Auto Script VPS to Create Trial VPN/SSH User
# Version : 1.2 (Hardening and UX refinement)
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

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

# --- Configuration Files ---
# IMPORTANT: Expand ~ to /root explicitly in scripts
LOG_FILE="/root/log-install.txt"

# --- Detect XRAY / V2RAY domain ---
DOMAIN_PATH="/etc/xray/domain"
if [ ! -f "$DOMAIN_PATH" ]; then
    DOMAIN_PATH="/etc/v2ray/domain"
fi

# Ensure domain is set, falling back to IP if file is missing
DOMAIN=$(cat "$DOMAIN_PATH" 2>/dev/null || echo "$MYIP")

# --- Extract service ports from log (using safer greps) ---
# Use the same fallback (|| echo "N/A") for consistency when log file is missing or empty
PORT_SSH_WS=$(grep -w "noneTLS" "$LOG_FILE" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "-")
PORT_SSH_SSL_WS=$(grep -w "TLS" "$LOG_FILE" 2>/dev/null | cut -d: -f2 | awk '{print $1}' || echo "-")
PORT_OPENSSH=$(grep -w "OpenSSH" "$LOG_FILE" 2>/dev/null | cut -d: -f2 | awk '{print $1,$2}' || echo "22")
PORT_DROPBEAR=$(grep -w "Dropbear" "$LOG_FILE" 2>/dev/null | cut -d: -f2 | awk '{print $1,$2}' || echo "109")
PORT_SSL=$(grep -w "Stunnel4" "$LOG_FILE" 2>/dev/null | cut -d: -f2 | awk '{print $1,$2}' || echo "444")

# --- Trial Account Settings ---
# Use a cleaner way to generate a 4-char alphanumeric random string
USER="trial$(head /dev/urandom | tr -dc a-z0-9 | head -c4)"
PASS="1"
DAYS_ACTIVE=1

# --- Create Trial Account ---
# -M: Don't create home directory
# -s /bin/false: Disable interactive shell login
# -e: Set expiration date
useradd -e "$(date -d "$DAYS_ACTIVE days" +"%Y-%m-%d")" -s /bin/false -M "$USER"
# Set password (suppressing all output)
echo -e "$PASS\n$PASS\n" | passwd "$USER" &>/dev/null

# Get formatted expiration date for display
EXP_DATE=$(chage -l "$USER" | grep "Account expires" | awk -F": " '{print $2}')

# --- Ask max login limit (for informational display) ---
read -rp "Enter max simultaneous logins (default=1): " MAX_LOGIN
MAX_LOGIN=${MAX_LOGIN:-1}

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}          ✅ TRIAL SSH ACCOUNT ✅          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Username   : ${green}$USER${nc}"
echo -e "Password   : ${green}$PASS${nc}"
echo -e "Expired On : ${yellow}$EXP_DATE${nc}"
echo -e "Max Login  : $MAX_LOGIN"
echo -e "${red}=========================================${nc}"
echo -e "IP         : $MYIP"
echo -e "Host       : $DOMAIN"
echo -e "OpenSSH    : $PORT_OPENSSH"
echo -e "Dropbear   : $PORT_DROPBEAR"
echo -e "Stunnel4   : $PORT_SSL"
echo -e "SSH WS     : $PORT_SSH_WS (No TLS)"
echo -e "SSH SSL WS : $PORT_SSH_SSL_WS (TLS)"
echo -e "UDPGW      : 7100-7900 (Proxy)"
echo -e "${red}=========================================${nc}"
echo -e "${blue}WebSocket Payloads (For Tunnel Apps):${nc}"
echo -e "${yellow}WSS Payload (Secure - Port $PORT_SSH_SSL_WS):${nc}"
echo -e "GET wss://bug.com HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "${red}-----------------------------------------${nc}"
echo -e "${yellow}WS Payload (Non-Secure - Port $PORT_SSH_WS):${nc}"
echo -e "GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "${red}=========================================${nc}"

read -n 1 -s -r -p "Press any key to return to menu..."
m-sshovpn 2>/dev/null || exit 0