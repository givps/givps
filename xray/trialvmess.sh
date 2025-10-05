#!/bin/bash
# =========================================
# Name    : trialvmess
# Title   : Create Trial VMESS Account
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
echo -e "${green}Creating Trial VMess Account...${nc}"

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
   '.inbounds[] |= if (.protocol == "vmess" and .streamSettings.network == "ws") then
        .settings.clients += [{"id": $uid, "alterId": 0, "email": $usr}]
     elif (.protocol == "vmess" and .streamSettings.network == "grpc") then
        .settings.clients += [{"id": $uid, "alterId": 0, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp 

if [[ $? -ne 0 ]]; then
  echo -e "${red}❌ Failed to update config.json! Reverting changes...${nc}"
  rm -f /tmp/config.json.tmp
  exit 1
fi

mv /tmp/config.json.tmp /etc/xray/config.json

# --- Simpan info trial (separate file for consistency) ---
mkdir -p /etc/xray/vmess/trial
echo "$exp" > "/etc/xray/vmess/trial/${user}.conf"
echo "$(date '+%Y-%m-%d %H:%M:%S') - VMESS Trial: $user | Exp: $exp" >> /etc/log-create-user.log

# --- Restart Xray ---
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# --- Buat link VMess (Base64 JSON) ---
wstls='{"v":"2","ps":"'"$user"'","add":"'"$domain"'","port":"'"$tls"'","id":"'"$uuid"'","aid":"0","net":"ws","path":"/vmess","type":"none","host":"'${domain}'","tls":"tls","sni":"'${domain}'"}'
wsnontls='{"v":"2","ps":"'"$user"'","add":"'"$domain"'","port":"'"$none"'","id":"'"$uuid"'","aid":"0","net":"ws","path":"/vmess","type":"none","host":"'${domain}'","tls":"none"}'
grpc='{"v":"2","ps":"'"$user"'","add":"'"$domain"'","port":"'"$tls"'","id":"'"$uuid"'","aid":"0","net":"grpc","path":"vmess-grpc","type":"none","host":"","tls":"tls","sni":"'${domain}'"}'

vmesslink1="vmess://$(echo -n "$wstls" | base64 -w 0)"
vmesslink2="vmess://$(echo -n "$wsnontls" | base64 -w 0)"
vmesslink3="vmess://$(echo -n "$grpc" | base64 -w 0)"

# --- Tampilkan hasil ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}           TRIAL VMESS ACCOUNT           ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks          : ${yellow}${user}${nc}"
echo -e "Domain           : ${yellow}${domain}${nc}"
echo -e "Port TLS         : ${yellow}${tls}${nc}"
echo -e "Port none TLS    : ${yellow}${none}${nc}"
echo -e "Port gRPC        : ${yellow}${tls}${nc}"
echo -e "ID               : ${yellow}${uuid}${nc}"
echo -e "AlterID          : ${yellow}0${nc}"
echo -e "Network          : ${yellow}ws / grpc${nc}"
echo -e "Path (WS)        : ${yellow}/vmess${nc}"
echo -e "ServiceName gRPC : ${yellow}vmess-grpc${nc}"
echo -e "Expired On       : ${yellow}${exp} (1 Day)${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (WS)    : ${vmesslink1}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS (WS): ${vmesslink2}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (gRPC)  : ${vmesslink3}"
echo -e "${red}=========================================${nc}"

# --- Install Auto-cleaner Script ---
CLEANER_SCRIPT="/usr/local/bin/vmess-cleaner"
echo -e "[ ${yellow}INFO${nc} ] Installing daily cleaner cron job..."

cat > "$CLEANER_SCRIPT" << 'EOF'
#!/bin/bash
# VMESS Trial Cleaner
CONFIG="/etc/xray/config.json"
TRIAL_DIR="/etc/xray/vmess/trial"
LOG="/var/log/vmess-cleaner.log"

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
    echo "$(date): Removing expired VMESS user: $user (Expired: $exp)" >> "$LOG"
    
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

# --- Add cron job (daily at 00:01) ---
(crontab -l 2>/dev/null | grep -v "vmess-cleaner"; echo "1 0 * * * $CLEANER_SCRIPT >/dev/null 2>&1") | crontab -

# --- Kembali ke menu ---
read -n 1 -s -r -p "Press any key to return to menu..."
if declare -f m-vmess >/dev/null 2>&1; then m-vmess; else exit 0; fi