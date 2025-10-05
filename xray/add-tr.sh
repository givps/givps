#!/bin/bash
# =========================================
# Name    : add-tr
# Title   : Auto Script VPS for Creating Trojan (Xray) Account
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
    echo -e "${blue}          Add TROJAN Account             ${nc}"
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
    mkdir -p /etc/trojan
    if [[ -f /etc/trojan/trojan-users ]] && grep -q "^$user " /etc/trojan/trojan-users; then
        echo -e "${red}❌ Username already exists!${nc}"
        read -n 1 -s -r -p "Press any key to return to menu..."
        type m-trojan &> /dev/null && m-trojan || exit 0
    else
        break
    fi
done

# --- Generate data ---
PASSWORD=$(cat /proc/sys/kernel/random/uuid)
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
jq --arg pwd "$PASSWORD" --arg usr "$user" \
   '.inbounds[] |= if (.protocol == "trojan" and .streamSettings.network == "ws") then
        .settings.clients += [{"password": $pwd, "email": $usr}]
     elif (.protocol == "trojan" and .streamSettings.network == "grpc") then
        .settings.clients += [{"password": $pwd, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp

if [[ $? -ne 0 ]] || [[ ! -s /tmp/config.json.tmp ]]; then
    echo -e "${red}❌ ERROR: Failed to update Xray config.json via jq! Check jq syntax or config.${nc}"
    rm -f /tmp/config.json.tmp
    exit 1
fi
mv /tmp/config.json.tmp /etc/xray/config.json

# --- Save to user database ---
echo "$user $PASSWORD $EXP_DATE" >> /etc/trojan/trojan-users

# --- Auto-cleaner setup (Ensure cron is only added once) ---
if [[ ! -f /usr/local/bin/trojan-cleaner ]]; then
    echo -e "[ ${green}INFO${nc} ] Setting up trojan-cleaner cron job..."
cat > /usr/local/bin/trojan-cleaner << 'EOF'
#!/bin/bash
USER_FILE="/etc/trojan/trojan-users"
CONFIG="/etc/xray/config.json"
TODAY_TS=$(date +%s)

[ ! -f "$USER_FILE" ] && exit 0

> "$USER_FILE.tmp"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  set -- $line
  user="$1"; pwd="$2"; exp="$3"
  exp_ts=$(date -d "$exp 00:00:00" +%s 2>/dev/null || echo 0)
  
  # Check if the expiration timestamp is less than or equal to today's timestamp
  if [ "$exp_ts" -le "$TODAY_TS" ] && [ "$exp_ts" -ne 0 ] 2>/dev/null; then
    echo "$(date): Removing expired user: $user" >> /var/log/trojan-cleaner.log
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
    chmod +x /usr/local/bin/trojan-cleaner
    # Add cron job if it doesn't exist
    if ! crontab -l 2>/dev/null | grep -q "trojan-cleaner"; then
        (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/trojan-cleaner >/dev/null 2>&1") | crontab -
    fi
fi

# --- Generate Trojan links ---
# WS-TLS link: trojan://password@domain:tls_port?path=/trojan&security=tls&host=domain&type=ws&sni=domain#tag
TROJAN_LINK_TLS="trojan://${PASSWORD}@${DOMAIN}:${TLS_PORT}?path=%2Ftrojan&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
# WS-NoneTLS link: trojan://password@domain:none_tls_port?path=/trojan&host=domain&type=ws#tag
TROJAN_LINK_NONE_TLS="trojan://${PASSWORD}@${DOMAIN}:${NONE_PORT}?path=%2Ftrojan&host=${DOMAIN}&type=ws#${user}"
# gRPC-TLS link: trojan://password@domain:tls_port?security=tls&type=grpc&serviceName=trojan-grpc&sni=domain#tag
TROJAN_LINK_GRPC="trojan://${PASSWORD}@${DOMAIN}:${TLS_PORT}?security=tls&type=grpc&serviceName=trojan-grpc&sni=${DOMAIN}#${user}"

# --- Restart Xray ---
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# --- Display account info ---
clear
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-trojan.log
echo -e "${blue}          TROJAN Account Created         ${nc}" | tee -a /etc/log-create-trojan.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Username       : ${yellow}${user}${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Host/IP        : ${yellow}${DOMAIN}${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Port TLS (WS/gRPC): ${yellow}${TLS_PORT}${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Port None TLS (WS): ${yellow}${NONE_PORT}${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Password       : ${yellow}${PASSWORD}${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Expired On     : ${yellow}${EXP_DATE}${nc}" | tee -a /etc/log-create-trojan.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-trojan.log
echo -e "  Link WS TLS (Recommended)  " | tee -a /etc/log-create-trojan.log
echo -e "${TROJAN_LINK_TLS}" | tee -a /etc/log-create-trojan.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-trojan.log
echo -e "  Link gRPC TLS  " | tee -a /etc/log-create-trojan.log
echo -e "${TROJAN_LINK_GRPC}" | tee -a /etc/log-create-trojan.log
echo -e "${red}-----------------------------------------${nc}" | tee -a /etc/log-create-trojan.log
echo -e "  Link WS None TLS  " | tee -a /etc/log-create-trojan.log
echo -e "${TROJAN_LINK_NONE_TLS}" | tee -a /etc/log-create-trojan.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-trojan.log

read -n 1 -s -r -p "Press any key to return to menu..."
# Safely return to menu function
type m-trojan &> /dev/null && m-trojan || exit 0