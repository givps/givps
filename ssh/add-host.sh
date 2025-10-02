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

# --- Get VPS public IP ---
IP=$(curl -s ipv4.icanhazip.com || wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Check XRAY installation
if grep -qw "XRAY" /root/log-install.txt 2>/dev/null; then
    cekray="XRAY Installed"
else
    cekray="Not Installed"
fi

echo -e "${red}=========================================${nc}"
echo -e "${blue}      Add / Change Domain + SSL     ${nc}"
echo -e "${red}=========================================${nc}"
echo -e " Current IP : $IP"
echo -e " XRAY Status: $cekray"
echo -e "${red}=========================================${nc}"
echo ""

read -rp "Enter Domain (example: mydomain.com): " domain
echo ""

if [[ -z "$domain" ]]; then
    echo -e "\033[0;31m[Error]\033[0m Domain cannot be empty!"
    read -n 1 -s -r -p "Press any key to return to menu..."
    m-domain
    exit 1
fi

# Save domain
echo "IP=$domain" > /var/lib/ipvps.conf
echo "$domain" | tee /root/domain /etc/xray/domain /etc/v2ray/domain >/dev/null
echo -e "\033[0;32m[OK]\033[0m Domain successfully set: $domain"

echo -e "${red}=========================================${nc}"
echo -e " Generating / Renewing SSL Certificate..."
echo -e "${red}=========================================${nc}"

# Install acme.sh if not installed
if [[ ! -f ~/.acme.sh/acme.sh ]]; then
    curl https://get.acme.sh | sh
    source ~/.bashrc
fi

# Set CA to Let's Encrypt
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --register-account -m admin@$domain --force

# Get Cloudflare API Token
if [[ -f /root/cf_api_token ]]; then
    CF_API_TOKEN=$(cat /root/cf_api_token)
else
    read -rp "Enter Cloudflare API Token: " CF_API_TOKEN
    echo "$CF_API_TOKEN" > /root/cf_api_token
fi
export CF_Token="$CF_API_TOKEN"
export CF_Account_ID="" # optional if token is account-based

# Issue SSL wildcard via DNS API
~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --force

# Install certs to xray folder
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d "$domain" \
    --key-file /etc/xray/xray.key \
    --fullchain-file /etc/xray/xray.crt \
    --reloadcmd "systemctl restart xray"

# Clean up old cron jobs (if any)
crontab -l 2>/dev/null | grep -v "acme.sh --cron" | crontab -

# Add auto-renew cron job (daily at 03:00 AM)
(crontab -l 2>/dev/null; echo "0 3 * * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null 2>&1") | crontab -

echo -e "\033[0;32m[OK]\033[0m SSL Certificate (wildcard) successfully issued/renewed."
echo -e "\033[0;32m[OK]\033[0m Auto-renew cron job has been set (schedule: 03:00 daily)."

echo -e "${red}=========================================${nc}"
read -n 1 -s -r -p "Press any key to return to menu..."
m-domain
