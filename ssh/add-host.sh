#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS to Create VPN on Debian & Ubuntu Server
# Version : 1.3 (Optimized for Persistent Cloudflare Token Storage)
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

# --- EMBEDDED CLOUDFLARE API TOKEN ---
# PERINGATAN: TOKEN TERTANAM. Pastikan file ini diamankan.
EMBEDDED_CF_API_TOKEN="BnzEPlSNz6HugXhHTH_nwgN4tHzi_ItVU_jxMI5k"
CF_TOKEN_FILE="/root/cf_api_token"
CF_ACCOUNT_FILE="/root/cf_account_id"

# Helper function for logging and exiting on error
error_exit() {
    echo -e "\033[0;31m[Error]\033[0m $1"
    read -n 1 -s -r -p "Press any key to return to menu..."
    # Attempt to return to the menu function if defined, otherwise exit script.
    m-domain 2>/dev/null || exit 1
}

# --- Get VPS public IP ---
IP=$(curl -s ipv4.icanhazip.com || wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Check XRAY installation status
if grep -qw "XRAY" /root/log-install.txt 2>/dev/null; then
    cekray="XRAY Installed"
else
    cekray="Not Installed"
fi

# --- Display Header and Get Domain ---
echo -e "${red}=========================================${nc}"
echo -e "${blue}      Add / Change Domain + SSL     ${nc}"
echo -e "${red}=========================================${nc}"
echo -e " Current IP : $IP"
echo -e " XRAY Status: $cekray"
echo -e " CF Token: ${green}EMBEDDED & SECURED${nc}"
echo -e "${red}=========================================${nc}"
echo ""

read -rp "Enter Domain (example: mydomain.com): " domain
echo ""

if [[ -z "$domain" ]]; then
    error_exit "Domain cannot be empty!"
fi

# Save domain configuration
echo "IP=$domain" > /var/lib/ipvps.conf
echo "$domain" | tee /root/domain /etc/xray/domain /etc/v2ray/domain >/dev/null
echo -e "\033[0;32m[OK]\033[0m Domain successfully set: $domain"

# --- Install acme.sh ---
ACME_SH_PATH="$HOME/.acme.sh/acme.sh"
if [[ ! -f "$ACME_SH_PATH" ]]; then
    echo -e "${yellow}Installing acme.sh...${nc}"
    curl https://get.acme.sh | sh || error_exit "Failed to install acme.sh."
fi

# Set CA and Register Account
"$ACME_SH_PATH" --set-default-ca --server letsencrypt
"$ACME_SH_PATH" --register-account -m admin@"$domain" || error_exit "Failed to register acme.sh account."


# --- Setup Cloudflare Credentials Permanently ---
echo -e "${red}=========================================${nc}"
echo -e " Storing Cloudflare Token for Persistent Renewal"
echo -e "${red}=========================================${nc}"

# 1. Save Token to File (for persistence and future runs)
if [[ ! -f "$CF_TOKEN_FILE" ]]; then
    echo "$EMBEDDED_CF_API_TOKEN" > "$CF_TOKEN_FILE"
    chmod 600 "$CF_TOKEN_FILE" # Secure the file
    echo -e "${green}Token saved and secured at $CF_TOKEN_FILE.${nc}"
else
    echo -e "${green}Token file $CF_TOKEN_FILE already exists.${nc}"
fi
CF_API_TOKEN=$(cat "$CF_TOKEN_FILE")

# 2. Handle Optional Account ID Input (only once)
CF_Account_ID=""
if [[ ! -f "$CF_ACCOUNT_FILE" ]]; then
    read -rp "Enter Cloudflare Account ID (optional, press Enter to skip): " CF_ACCOUNT_ID_INPUT
    if [[ -n "$CF_ACCOUNT_ID_INPUT" ]]; then
        echo "$CF_ACCOUNT_ID_INPUT" > "$CF_ACCOUNT_FILE"
        chmod 600 "$CF_ACCOUNT_FILE"
        CF_Account_ID="$CF_ACCOUNT_ID_INPUT"
    fi
else
    CF_Account_ID=$(cat "$CF_ACCOUNT_FILE")
fi

# 3. Use acme.sh's built-in command to set credentials persistently
echo -e "${yellow}Setting CF_Token and CF_Account_ID in acme.sh configuration...${nc}"
# Set token (required)
"$ACME_SH_PATH" --set-server-config --key CF_Token --value "$CF_API_TOKEN"
# Set account ID (optional)
if [[ -n "$CF_Account_ID" ]]; then
    "$ACME_SH_PATH" --set-server-config --key CF_Account_ID --value "$CF_Account_ID"
fi
echo -e "\033[0;32m[OK]\033[0m Cloudflare credentials configured for auto-renewal."


# --- Issue SSL wildcard via DNS API ---
echo -e "${red}=========================================${nc}"
echo -e " Generating / Renewing Wildcard SSL Certificate..."
echo -e "${red}=========================================${nc}"

# Note: acme.sh automatically uses the persistently set CF_Token/CF_Account_ID
if ! "$ACME_SH_PATH" --issue --dns dns_cf -d "$domain" -d "*.$domain"; then
    error_exit "Failed to issue/renew wildcard SSL certificate. Check Cloudflare DNS/API permissions."
fi

# --- Install certs to xray folder ---
mkdir -p /etc/xray /etc/v2ray
echo -e "${yellow}Installing certificate files and restarting Xray...${nc}"
if ! "$ACME_SH_PATH" --install-cert -d "$domain" \
    --key-file /etc/xray/xray.key \
    --fullchain-file /etc/xray/xray.crt \
    --reloadcmd "systemctl restart xray 2>/dev/null"; then
    error_exit "Failed to install SSL certificate."
fi

# Copy certs to v2ray directory for compatibility
cp /etc/xray/xray.key /etc/v2ray/xray.key 2>/dev/null
cp /etc/xray/xray.crt /etc/v2ray/xray.crt 2>/dev/null
systemctl restart v2ray 2>/dev/null

# --- Setup Auto-Renew Cron Job ---
echo -e "${yellow}Setting up auto-renewal cron job...${nc}"
# Clean up old acme.sh cron jobs (using grep -v to remove existing entries)
crontab -l 2>/dev/null | grep -v "acme.sh --cron" | crontab -

# Add auto-renew cron job (daily at 03:00 AM)
# Cron job now relies on the persistent configuration and only needs to call --cron.
(crontab -l 2>/dev/null; echo "0 3 * * * $ACME_SH_PATH --cron > /dev/null 2>&1") | crontab -

echo -e "\033[0;32m[OK]\033[0m SSL Certificate (wildcard) successfully issued/renewed."
echo -e "\033[0;32m[OK]\033[0m Auto-renew cron job has been set (schedule: 03:00 daily)."
echo -e "${red}=========================================${nc}"

read -n 1 -s -r -p "Press any key to return to menu..."
m-domain 2>/dev/null || exit 0