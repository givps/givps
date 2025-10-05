#!/bin/bash
# =========================================
# Name    : trialvless
# Title   : Create Trial VLESS Account
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
echo -e "${green}Creating Trial VLESS Account...${nc}"

# --- Check necessary files ---
DOMAIN_FILE="/etc/xray/domain"
LOG_FILE="~/log-install.txt"

[[ ! -f "$DOMAIN_FILE" ]] && { echo -e "${red}❌ Domain file not found at $DOMAIN_FILE!${nc}"; exit 1; }
[[ ! -f $LOG_FILE ]] && { echo -e "${red}❌ log-install.txt not found!${nc}"; exit 1; }

domain=$(cat "$DOMAIN_FILE")

# Assuming log-install.txt format is consistent: "TLS Port: 443" / "noneTLS Port: 80"
tls=$(grep -w "TLS Port" "$LOG_FILE" | awk '{print $NF}')
none=$(grep -w "noneTLS Port" "$LOG_FILE" | awk '{print $NF}')

[[ -z "$tls" || -z "$none" ]] && { echo -e "${red}❌ Port info (TLS/noneTLS) missing in log-install.txt!${nc}"; exit 1; }

# --- Check/Install jq ---
if ! command -v jq &> /dev/null; then
  echo -e "${yellow}Installing jq for JSON manipulation...${nc}"
  apt update && apt install -y jq || { echo -e "${red}❌ Failed to install jq!${nc}"; exit 1; }
fi

# --- Generate user ---
user="trial$(tr -dc 'A-Z0-9' </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "+1 day" +"%Y-%m-%d")

# --- Tambahkan ke config.json (multi-user) ---
echo -e "[ ${green}INFO${nc} ] Adding new user '$user' to Xray config..."
jq --arg uid "$uuid" --arg usr "$user" \
   '.inbounds[] |= if (.protocol == "vless" and .streamSettings.network == "ws") then
        .settings.clients += [{"id": $uid, "email": $usr}]
     elif (.protocol == "vless" and .streamSettings.network == "grpc") then
        .settings.clients += [{"id": $uid, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp 

if [[ $? -ne 0 ]]; then
  echo -e "${red}❌ Failed to update config.json! Reverting changes...${nc}"
  rm -f /tmp/config.json.tmp
  exit 1
fi

mv /tmp/config.json.tmp /etc/xray/config.json

# --- Simpan info trial ---
mkdir -p /etc/vless/trial
echo "$exp" > "/etc/vless/trial/${user}.conf"
echo "$(date '+%Y-%m-%d %H:%M:%S') - VLESS Trial: $user | Exp: $exp" >> /etc/log-create-user.log

# --- Restart Xray ---
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# --- Buat link VLESS ---
vlesslink1="vless://${uuid}@${domain}:${tls}?path=/vless&security=tls&encryption=none&type=ws&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:${none}?path=/vless&encryption=none&type=ws#${user}"
# Mode=gun is common for VLESS/gRPC
vlesslink3="vless://${uuid}@${domain}:${tls}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"

# --- Tampilkan hasil ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}           TRIAL VLESS ACCOUNT           ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks          : ${yellow}${user}${nc}"
echo -e "Domain           : ${yellow}${domain}${nc}"
echo -e "Port TLS         : ${yellow}${tls}${nc}"
echo -e "Port none TLS    : ${yellow}${none}${nc}"
echo -e "Port gRPC        : ${yellow}${tls}${nc}"
echo -e "ID               : ${yellow}${uuid}${nc}"
echo -e "Encryption       : ${yellow}none${nc}"
echo -e "Network          : ${yellow}ws / grpc${nc}"
echo -e "Path (WS)        : ${yellow}/vless${nc}"
echo -e "ServiceName gRPC : ${yellow}vless-grpc${nc}"
echo -e "Expired On       : ${yellow}${exp} (1 Day)${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (WS)    : ${vlesslink1}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS (WS): ${vlesslink2}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (gRPC)  : ${vlesslink3}"
echo -e "${red}=========================================${nc}"

# --- Install Auto-cleaner Script ---
CLEANER_SCRIPT="/usr/local/bin/vless-cleaner"
echo -e "[ ${yellow}INFO${nc} ] Installing daily cleaner cron job..."

cat > "$CLEANER_SCRIPT" << 'EOF'
#!/bin/bash
# VLESS Trial Cleaner
CONFIG="/etc/xray/config.json"
TRIAL_DIR="/etc/vless/trial"
LOG="/var/log/vless-cleaner.log"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "$(date): ERROR: jq not found for cleaning. Exiting." >> "$LOG"
    exit 1
fi

mkdir -p "$(dirname "$LOG")"
touch "$LOG"

for file in "$TRIAL_DIR"/*.conf; do
  [ -e "$file" ] || continue
  user=$(basename "$file" .conf)
  exp=$(cat "$file")
  exp_ts=$(date -d "$exp" +%s 2>/dev/null || echo 0)
  now_ts=$(date +%s)

  if [ "$exp_ts" -le "$now_ts" ] 2>/dev/null; then
    echo "$(date): Removing expired VLESS user: $user (Expired: $exp)" >> "$LOG"
    
    # Hapus dari config.json
    if jq --arg u "$user" 'del(.inbounds[]?.settings.clients[]? | select(.email == $u))' "$CONFIG" > "$CONFIG.tmp"; then
        mv "$CONFIG.tmp" "$CONFIG"
        rm -f "$file"
    else
        echo "$(date): WARNING: Failed to remove $user from config.json using jq." >> "$LOG"
    fi
  fi
done

# Restart Xray only if config was potentially modified (to ensure changes apply)
if [ -f "$CONFIG.tmp" ]; then
    systemctl restart xray
fi
EOF

chmod +x "$CLEANER_SCRIPT"

# --- Add cron job (daily at 00:10) ---
(crontab -l 2>/dev/null | grep -v "vless-cleaner"; echo "10 0 * * * $CLEANER_SCRIPT >/dev/null 2>&1") | crontab -

# --- Kembali ke menu ---
read -n 1 -s -r -p "Press any key to return to menu..."
if declare -f m-vless >/dev/null 2>&1; then m-vless; else exit 0; fi