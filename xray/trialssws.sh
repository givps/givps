#!/bin/bash
# =========================================
# Name    : trialssws
# Title   : Create Trial Shadowsocks Account
# Version : 1.2 (Revised)
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

clear
echo -e "${green}Creating Trial Shadowsocks Account...${nc}"

# --- Check necessary files ---
DOMAIN_FILE="/etc/xray/domain"
LOG_FILE="~/log-install.txt"

[[ ! -f "$DOMAIN_FILE" ]] && { echo -e "${red}❌ Domain file not found at $DOMAIN_FILE!${nc}"; exit 1; }
[[ ! -f $LOG_FILE ]] && { echo -e "${red}❌ log-install.txt not found!${nc}"; exit 1; }

domain=$(cat "$DOMAIN_FILE")
# Assuming log-install.txt format is consistent:
# TLS Port: 443
# noneTLS Port: 80
tls=$(grep -w "TLS Port" "$LOG_FILE" | awk '{print $NF}')
none=$(grep -w "noneTLS Port" "$LOG_FILE" | awk '{print $NF}')

[[ -z "$tls" || -z "$none" ]] && { echo -e "${red}❌ Port info (TLS/noneTLS) missing in log-install.txt!${nc}"; exit 1; }

# --- Check/Install jq ---
if ! command -v jq &> /dev/null; then
  echo -e "${yellow}Installing jq for JSON manipulation...${nc}"
  apt update && apt install -y jq || { echo -e "${red}❌ Failed to install jq!${nc}"; exit 1; }
fi

# --- Install/Update Cleaner Script and Cron Job ---
CLEANER_SCRIPT="/usr/local/bin/ss-cleaner"
mkdir -p /etc/shadowsocks/trial

# Create the dedicated cleaner script
cat > "$CLEANER_SCRIPT" << EOF
#!/bin/bash
# Shadowsocks Trial Cleaner
USER_DIR="/etc/shadowsocks/trial"
CONFIG="/etc/xray/config.json"
TODAY_TS=\$(date +%s)
LOG_CLEANER="/var/log/ss-cleaner.log"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "\$(date): ERROR: jq not found for cleaning. Exiting." >> "\$LOG_CLEANER"
    exit 1
fi

for file in "\$USER_DIR"/*.conf; do
    [ -e "\$file" ] || continue
    user=\$(basename "\$file" .conf)
    exp=\$(cat "\$file")
    exp_ts=\$(date -d "\$exp" +%s 2>/dev/null || echo 0)

    if [ "\$exp_ts" -le "\$TODAY_TS" ] 2>/dev/null; then
        echo "\$(date): Removing expired SS trial user: \$user (Expired: \$exp)" >> "\$LOG_CLEANER"
        
        # Hapus dari config.json
        if jq --arg u "\$user" 'del(.inbounds[]?.settings.clients[]? | select(.email == \$u))' "\$CONFIG" > "\$CONFIG.tmp"; then
             mv "\$CONFIG.tmp" "\$CONFIG"
             rm -f "\$file"
        else
             echo "\$(date): WARNING: Failed to remove \$user from config.json using jq." >> "\$LOG_CLEANER"
        fi
    fi
done

# Restart Xray only if config was potentially modified (to ensure changes apply)
if [ -f "\$CONFIG.tmp" ]; then
    systemctl restart xray
fi
EOF

chmod +x "$CLEANER_SCRIPT"

# Set up cron job (daily at 00:15)
echo -e "[ ${yellow}INFO${nc} ] Setting up daily cleaner cron job."
(crontab -l 2>/dev/null | grep -v "ss-cleaner"; echo "15 0 * * * $CLEANER_SCRIPT >/dev/null 2>&1") | crontab -

# === Generate new user ===
user="trial$(tr -dc 'A-Z0-9' </dev/urandom | head -c4)"
cipher="aes-128-gcm"
password=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "+1 day" +"%Y-%m-%d")

# === Add to config.json ===
echo -e "[ ${green}INFO${nc} ] Adding new user '$user' to Xray config..."
jq --arg pwd "$password" --arg usr "$user" --arg method "$cipher" \
   '.inbounds[] |= if (.protocol == "shadowsocks" and .streamSettings.network == "ws") then
        .settings.clients += [{"method": $method, "password": $pwd, "email": $usr}]
     elif (.protocol == "shadowsocks" and .streamSettings.network == "grpc") then
        .settings.clients += [{"method": $method, "password": $pwd, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp 

if [[ $? -ne 0 ]]; then
  echo -e "${red}❌ Failed to update config.json! Reverting changes...${nc}"
  rm -f /tmp/config.json.tmp
  exit 1
fi

mv /tmp/config.json.tmp /etc/xray/config.json

# === Restart Xray ===
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# === Create Shadowsocks links ===
# Note: Xray-compatible Shadowsocks links for WS/gRPC often require non-standard parameters (type, host, path/serviceName)
ss_link_tls="ss://$(echo -n "$cipher:$password" | base64 -w 0)@${domain}:${tls}?path=%2Fss-ws&security=tls&type=ws&host=${domain}&sni=${domain}#${user}"
ss_link_none="ss://$(echo -n "$cipher:$password" | base64 -w 0)@${domain}:${none}?path=%2Fss-ws&type=ws&host=${domain}#${user}"
ss_link_grpc="ss://$(echo -n "$cipher:$password" | base64 -w 0)@${domain}:${tls}?security=tls&type=grpc&serviceName=ss-grpc&sni=${domain}#${user}"

# === Save info ===
echo "$(date '+%Y-%m-%d %H:%M:%S') - Shadowsocks Trial: $user | Exp: $exp" >> /etc/log-create-user.log
echo "$exp" > "/etc/shadowsocks/trial/${user}.conf"

# === Display result ===
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}          SHADOWSOCKS TRIAL ACCOUNT      ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks        : ${yellow}${user}${nc}"
echo -e "Domain         : ${yellow}${domain}${nc}"
echo -e "Port TLS       : ${yellow}${tls}${nc}"
echo -e "Port none TLS  : ${yellow}${none}${nc}"
echo -e "Port gRPC      : ${yellow}${tls}${nc}"
echo -e "Password       : ${yellow}${password}${nc}"
echo -e "Cipher         : ${yellow}${cipher}${nc}"
echo -e "Network        : ${yellow}ws / grpc${nc}"
echo -e "Path (WS)      : ${yellow}/ss-ws${nc}"
echo -e "Service Name   : ${yellow}ss-grpc${nc}"
echo -e "Expired On     : ${yellow}${exp} (1 Day)${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (WS)  : ${ss_link_tls}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS (WS): ${ss_link_none}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (gRPC): ${ss_link_grpc}"
echo -e "${red}=========================================${nc}"

# === Kembali ke menu ===
read -n 1 -s -r -p "Press any key to return to menu"
return_to_menu