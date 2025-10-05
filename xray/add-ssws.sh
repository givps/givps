#!/bin/bash
# =========================================
# Name    : add-ssws
# Title   : Auto Script VPS For Creating Shadowsocks (Xray) Account
# Version : 1.1 (Revised)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # No Color (reset)

clear
echo -e "${green}Checking VPS...${nc}"

# --- Load domain ---
if [[ -f /var/lib/ipvps.conf ]]; then
    # Prioritize IP from ipvps.conf, fallback to domain file
    source /var/lib/ipvps.conf
    DOMAIN=${IP:-$(cat /etc/xray/domain 2>/dev/null)}
else
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
fi

[[ -z "$DOMAIN" ]] && { echo -e "${red}❌ ERROR: Domain not found in /etc/xray/domain.${nc}"; exit 1; }

# --- Load ports with robust defaults ---
# Ports are sourced from log-install.txt or defaulted to 443 (TLS) and 80 (None-TLS)
TLS_PORT=$(grep -w "TLS" ~/log-install.txt 2>/dev/null | cut -d: -f2 | tr -d ' ')
NONE_PORT=$(grep -w "noneTLS" ~/log-install.txt 2>/dev/null | cut -d: -f2 | tr -d ' ')

TLS_PORT=${TLS_PORT:-"443"}
NONE_PORT=${NONE_PORT:-"80"}

# --- Install jq if not exists ---
if ! command -v jq &> /dev/null; then
    echo -e "[ ${yellow}INFO${nc} ] Installing jq..."
    apt update -qq && apt install -y jq
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ ERROR: Failed to install jq.${nc}"; exit 1
    fi
fi

# --- Input username ---
while true; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        Add Shadowsocks Account          ${nc}"
    echo -e "${red}=========================================${nc}"
    read -rp "Username (Alphanumeric only): " -e user

    if [[ -z "$user" ]]; then
        echo -e "${yellow}⚠ Username cannot be empty.${nc}"; continue
    fi

    # Stronger username validation: allow only a-z, A-Z, 0-9, and underscore
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "${red}❌ Invalid username! Use only letters, numbers, and underscore.${nc}"; continue
    fi

    # Check for duplicate in user file
    mkdir -p /etc/shadowsocks
    if [[ -f /etc/shadowsocks/ss-users ]] && grep -q "^$user " /etc/shadowsocks/ss-users; then
        echo -e "${red}❌ Username already exists!${nc}"
        read -n 1 -s -r -p "Press any key to return to menu..."
        # Safely exit if m-ssws is not a defined function
        type m-ssws &> /dev/null && m-ssws || exit 0
    else
        break
    fi
done

# --- Generate data ---
CIPHER="aes-128-gcm"
PASSWORD=$(cat /proc/sys/kernel/random/uuid)
read -rp "Expired (days): " expired
# Default to 1 day if input is empty or invalid
if ! [[ "$expired" =~ ^[0-9]+$ ]] || [[ "$expired" -le 0 ]]; then
    echo -e "${yellow}⚠ Invalid/empty expiration set. Defaulting to 1 day.${nc}"
    expired=1
fi
EXP_DATE=$(date -d "$expired days" +"%Y-%m-%d")

# --- Add to config.json using jq (safe JSON manipulation) ---
echo -e "[ ${green}INFO${nc} ] Updating Xray config..."
jq --arg pwd "$PASSWORD" --arg method "$CIPHER" --arg usr "$user" \
   '.inbounds[] |= if (.protocol == "shadowsocks" and .streamSettings.network == "ws") then
        .settings.clients += [{"method": $method, "password": $pwd, "email": $usr}]
     elif (.protocol == "shadowsocks" and .streamSettings.network == "grpc") then
        .settings.clients += [{"method": $method, "password": $pwd, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp

if [[ $? -ne 0 ]] || [[ ! -s /tmp/config.json.tmp ]]; then
    echo -e "${red}❌ ERROR: Failed to update Xray config.json via jq! Check jq syntax or config.${nc}"
    rm -f /tmp/config.json.tmp
    exit 1
fi
mv /tmp/config.json.tmp /etc/xray/config.json

# --- Save to user database ---
echo "$user $PASSWORD $CIPHER $EXP_DATE" >> /etc/shadowsocks/ss-users

# --- Generate Shadowsocks links (Base64 encoding) ---
SS_B64=$(echo -n "$CIPHER:$PASSWORD" | base64 -w 0)

# WS-TLS link: ss://method:password@domain:tls_port?path=/ss-ws&security=tls&type=ws&sni=domain#tag
SS_LINK_TLS="ss://${SS_B64}@${DOMAIN}:${TLS_PORT}?path=%2Fss-ws&security=tls&type=ws&sni=${DOMAIN}#${user}"
# WS-NoneTLS link: ss://method:password@domain:none_tls_port?path=/ss-ws&type=ws#tag
SS_LINK_NONE_TLS="ss://${SS_B64}@${DOMAIN}:${NONE_PORT}?path=%2Fss-ws&type=ws#${user}"
# gRPC-TLS link: ss://method:password@domain:tls_port?security=tls&type=grpc&serviceName=ss-grpc&sni=domain#tag
SS_LINK_GRPC="ss://${SS_B64}@${DOMAIN}:${TLS_PORT}?security=tls&type=grpc&serviceName=ss-grpc&sni=${DOMAIN}#${user}"


# --- Create client config file ---
mkdir -p /home/vps/public_html
cat > /home/vps/public_html/ss-$user.txt <<-END
{
  "remarks": "$user",
  "address": "$DOMAIN",
  "port_tls": "$TLS_PORT",
  "port_none_tls": "$NONE_PORT",
  "port_grpc": "$TLS_PORT",
  "password": "$PASSWORD",
  "method": "$CIPHER",
  "network": "ws/grpc",
  "path": "/ss-ws",
  "serviceName": "ss-grpc",
  "link_tls": "$SS_LINK_TLS",
  "link_none_tls": "$SS_LINK_NONE_TLS",
  "link_grpc": "$SS_LINK_GRPC",
  "expired_on": "$EXP_DATE"
}
END

# --- Auto-cleaner setup (Ensure cron is only added once) ---
if [[ ! -f /usr/local/bin/ss-cleaner ]]; then
    echo -e "[ ${green}INFO${nc} ] Setting up ss-cleaner cron job..."
cat > /usr/local/bin/ss-cleaner << 'EOF'
#!/bin/bash
USER_FILE="/etc/shadowsocks/ss-users"
CONFIG="/etc/xray/config.json"
TODAY_TS=$(date +%s)

[ ! -f "$USER_FILE" ] && exit 0

> "$USER_FILE.tmp"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  set -- $line
  user="$1"; pwd="$2"; method="$3"; exp="$4"
  # Use date -d to parse expiration date string to timestamp
  exp_ts=$(date -d "$exp 00:00:00" +%s 2>/dev/null || echo 0)
  
  # Check if the expiration timestamp is less than or equal to today's timestamp
  if [ "$exp_ts" -le "$TODAY_TS" ] && [ "$exp_ts" -ne 0 ] 2>/dev/null; then
    echo "$(date): Removing expired user: $user" >> /var/log/ss-cleaner.log
    # Remove client from Xray config by email/tag
    jq --arg u "$user" 'del(.inbounds[]?.settings.clients[]? | select(.email == $u))' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  else
    # Keep the user if not expired
    echo "$line" >> "$USER_FILE.tmp"
  fi
done < "$USER_FILE"

# Replace old user file with non-expired users
mv "$USER_FILE.tmp" "$USER_FILE"
systemctl restart xray
EOF
    chmod +x /usr/local/bin/ss-cleaner
    # Add cron job if it doesn't exist
    if ! crontab -l 2>/dev/null | grep -q "ss-cleaner"; then
        (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/ss-cleaner >/dev/null 2>&1") | crontab -
    fi
fi

# --- Restart Xray ---
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# --- Display account info ---
clear
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${blue}           Shadowsocks Account           ${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Username       : ${yellow}${user}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Domain         : ${yellow}${DOMAIN}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Port TLS (WS/gRPC): ${yellow}${TLS_PORT}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Port None TLS (WS): ${yellow}${NONE_PORT}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Password       : ${yellow}${PASSWORD}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Cipher         : ${yellow}${CIPHER}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Expired On     : ${yellow}${EXP_DATE}${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "  Link WS TLS (Recommended)  " | tee -a /etc/log-create-shadowsocks.log
echo -e "${SS_LINK_TLS}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "  Link gRPC TLS  " | tee -a /etc/log-create-shadowsocks.log
echo -e "${SS_LINK_GRPC}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "  Link WS None TLS  " | tee -a /etc/log-create-shadowsocks.log
echo -e "${SS_LINK_NONE_TLS}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-shadowsocks.log

read -n 1 -s -r -p "Press any key to return to menu..."
# Safely return to menu function
type m-ssws &> /dev/null && m-ssws || exit 0