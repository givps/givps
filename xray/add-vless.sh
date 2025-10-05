#!/bin/bash
# =========================================
# Name    : add-vless
# Title   : Auto Script VPS for Creating VLESS (Xray) Account
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
    source /var/lib/ipvps.conf
    DOMAIN=${IP:-$(cat /etc/xray/domain 2>/dev/null)}
else
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
fi

[[ -z "$DOMAIN" ]] && { echo -e "${red}❌ ERROR: Domain not found in /etc/xray/domain.${nc}"; exit 1; }

# --- Load ports with robust defaults ---
TLS_PORT=$(grep -w "TLS" ~/log-install.txt 2>/dev/null | cut -d: -f2 | tr -d ' ')
NONE_PORT=$(grep -w "noneTLS" ~/log-install.txt 2>/dev/null | cut -d: -f2 | tr -d ' ')

TLS_PORT=${TLS_PORT:-"443"}
NONE_PORT=${NONE_PORT:-"80"}

# --- Input username ---
while true; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Add VLESS Account              ${nc}"
    echo -e "${red}=========================================${nc}"
    read -rp "Enter Username (Alphanumeric only): " -e user

    if [[ -z "$user" ]]; then
        echo -e "${yellow}⚠ Username cannot be empty.${nc}"; continue
    fi

    # Stronger username validation
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "${red}❌ Invalid username! Use only letters, numbers, and underscore.${nc}"; continue
    fi

    # Check for duplicate in user file
    mkdir -p /etc/xray
    if [[ -f /etc/xray/vless-users ]] && grep -q "^$user " /etc/xray/vless-users; then
        echo -e "${red}❌ Username already exists!${nc}"
        read -n 1 -s -r -p "Press any key to return to menu..."
        type m-vless &> /dev/null && m-vless || exit 0
    else
        break
    fi
done

# --- Generate data ---
UUID=$(cat /proc/sys/kernel/random/uuid)
read -rp "Expired (days): " expired
# Check if input is empty or non-positive
if ! [[ "$expired" =~ ^[0-9]+$ ]] || [[ "$expired" -le 0 ]]; then
    echo -e "${yellow}⚠ Invalid/empty expiration set. Defaulting to 1 day.${nc}"
    expired=1
fi
EXP_DATE=$(date -d "$expired days" +"%Y-%m-%d")

# --- Install jq if not exists ---
if ! command -v jq &> /dev/null; then
    echo -e "[ ${yellow}INFO${nc} ] Installing jq..."
    apt update -qq && apt install -y jq
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ ERROR: Failed to install jq.${nc}"; exit 1
    fi
fi

# --- Add to config.json using jq (safe JSON manipulation) ---
echo -e "[ ${green}INFO${nc} ] Updating Xray config..."
jq --arg uid "$UUID" --arg usr "$user" \
   '.inbounds[] |= if (.protocol == "vless" and .streamSettings.network == "ws") then
        .settings.clients += [{"id": $uid, "email": $usr}]
     elif (.protocol == "vless" and .streamSettings.network == "grpc") then
        .settings.clients += [{"id": $uid, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp

if [[ $? -ne 0 ]] || [[ ! -s /tmp/config.json.tmp ]]; then
    echo -e "${red}❌ ERROR: Failed to update Xray config.json via jq! Check jq syntax or config.${nc}"
    rm -f /tmp/config.json.tmp
    exit 1
fi
mv /tmp/config.json.tmp /etc/xray/config.json

# --- Save to user database ---
echo "$user $UUID $EXP_DATE" >> /etc/xray/vless-users

# --- Auto-cleaner setup (Ensure cron is only added once) ---
if [[ ! -f /usr/local/bin/vless-cleaner ]]; then
    echo -e "[ ${green}INFO${nc} ] Setting up vless-cleaner cron job..."
cat > /usr/local/bin/vless-cleaner << 'EOF'
#!/bin/bash
USER_FILE="/etc/xray/vless-users"
CONFIG="/etc/xray/config.json"
TODAY_TS=$(date +%s)

[ ! -f "$USER_FILE" ] && exit 0

> "$USER_FILE.tmp"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  set -- $line
  user="$1"; uuid="$2"; exp="$3"
  # Use date -d to parse expiration date string to timestamp
  exp_ts=$(date -d "$exp 00:00:00" +%s 2>/dev/null || echo 0)
  
  # Check if the expiration timestamp is less than or equal to today's timestamp
  if [ "$exp_ts" -le "$TODAY_TS" ] && [ "$exp_ts" -ne 0 ] 2>/dev/null; then
    echo "$(date): Removing expired user: $user" >> /var/log/vless-cleaner.log
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
    chmod +x /usr/local/bin/vless-cleaner
    # Add cron job if it doesn't exist
    if ! crontab -l 2>/dev/null | grep -q "vless-cleaner"; then
        (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/vless-cleaner >/dev/null 2>&1") | crontab -
    fi
fi

# --- Generate VLESS links ---
# WS-TLS link: vless://uuid@domain:tls_port?path=/vless&security=tls&encryption=none&type=ws&sni=domain#tag
VLESS_LINK_TLS="vless://${UUID}@${DOMAIN}:${TLS_PORT}?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${DOMAIN}#${user}"
# WS-NoneTLS link: vless://uuid@domain:none_tls_port?path=/vless&encryption=none&type=ws#tag
VLESS_LINK_NONE_TLS="vless://${UUID}@${DOMAIN}:${NONE_PORT}?path=%2Fvless&encryption=none&type=ws#${user}"
# gRPC-TLS link: vless://uuid@domain:tls_port?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=domain#tag
VLESS_LINK_GRPC="vless://${UUID}@${DOMAIN}:${TLS_PORT}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${DOMAIN}#${user}"

# --- Restart Xray ---
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# --- Display account info ---
clear
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vless.log
echo -e "${blue}          VLESS Account Created          ${nc}" | tee -a /etc/log-create-vless.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vless.log
echo -e "Username       : ${yellow}${user}${nc}" | tee -a /etc/log-create-vless.log
echo -e "Domain         : ${yellow}${DOMAIN}${nc}" | tee -a /etc/log-create-vless.log
echo -e "Port TLS (WS/gRPC): ${yellow}${TLS_PORT}${nc}" | tee -a /etc/log-create-vless.log
echo -e "Port None TLS (WS): ${yellow}${NONE_PORT}${nc}" | tee -a /etc/log-create-vless.log
echo -e "UUID           : ${yellow}${UUID}${nc}" | tee -a /etc/log-create-vless.log
echo -e "Expired On     : ${yellow}${EXP_DATE}${nc}" | tee -a /etc/log-create-vless.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-vless.log
echo -e "  Link WS TLS (Recommended)  " | tee -a /etc/log-create-vless.log
echo -e "${VLESS_LINK_TLS}" | tee -a /etc/log-create-vless.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-vless.log
echo -e "  Link gRPC TLS  " | tee -a /etc/log-create-vless.log
echo -e "${VLESS_LINK_GRPC}" | tee -a /etc/log-create-vless.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-vless.log
echo -e "  Link WS None TLS  " | tee -a /etc/log-create-vless.log
echo -e "${VLESS_LINK_NONE_TLS}" | tee -a /etc/log-create-vless.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vless.log

read -n 1 -s -r -p "Press any key to return to the menu..."
# Safely return to menu function
type m-vless &> /dev/null && m-vless || exit 0