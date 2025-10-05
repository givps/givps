#!/bin/bash
# =========================================
# Name    : trialtrojan
# Title   : Create Trial Trojan Account
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
echo -e "${green}Creating Trial Trojan Account...${nc}"

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
password=$(cat /proc/sys/kernel/random/uuid) # Trojan uses password
exp=$(date -d "+1 day" +"%Y-%m-%d")

# --- Tambahkan ke config.json (multi-user) ---
echo -e "[ ${green}INFO${nc} ] Adding new user '$user' to Xray config..."
jq --arg pwd "$password" --arg usr "$user" \
   '.inbounds[] |= if (.protocol == "trojan" and .streamSettings.network == "ws") then
        .settings.clients += [{"password": $pwd, "email": $usr}]
     elif (.protocol == "trojan" and .streamSettings.network == "grpc") then
        .settings.clients += [{"password": $pwd, "email": $usr}]
     else . end' \
   /etc/xray/config.json > /tmp/config.json.tmp 

if [[ $? -ne 0 ]]; then
  echo -e "${red}❌ Failed to update config.json! Reverting changes...${nc}"
  rm -f /tmp/config.json.tmp
  exit 1
fi

mv /tmp/config.json.tmp /etc/xray/config.json

# --- Simpan info trial ---
mkdir -p /etc/trojan/trial
echo "$exp" > "/etc/trojan/trial/${user}.conf"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Trojan Trial: $user | Exp: $exp" >> /etc/log-create-user.log

# --- Restart Xray ---
echo -e "[ ${green}INFO${nc} ] Restarting Xray service..."
systemctl restart xray

# --- Buat link Trojan ---
trojanlink_tls="trojan://${password}@${domain}:${tls}?path=%2Ftrojan&security=tls&type=ws&host=${domain}&sni=${domain}#${user}"
trojanlink_none="trojan://${password}@${domain}:${none}?path=%2Ftrojan&type=ws&host=${domain}#${user}"
trojanlink_grpc="trojan://${password}@${domain}:${tls}?security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

# --- Tampilkan hasil ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}           TRIAL TROJAN ACCOUNT          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks        : ${yellow}${user}${nc}"
echo -e "Host / Domain  : ${yellow}${domain}${nc}"
echo -e "Port TLS       : ${yellow}${tls}${nc}"
echo -e "Port none TLS  : ${yellow}${none}${nc}"
echo -e "Port gRPC      : ${yellow}${tls}${nc}"
echo -e "Password       : ${yellow}${password}${nc}"
echo -e "Network        : ${yellow}ws / grpc${nc}"
echo -e "Path (WS)      : ${yellow}/trojan${nc}"
echo -e "Service Name   : ${yellow}trojan-grpc${nc}"
echo -e "Expired On     : ${yellow}${exp} (1 Day)${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (WS)  : ${trojanlink_tls}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS (WS): ${trojanlink_none}"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS (gRPC): ${trojanlink_grpc}"
echo -e "${red}=========================================${nc}"

# --- Install Auto-cleaner Script ---
CLEANER_SCRIPT="/usr/local/bin/trojan-cleaner"
echo -e "[ ${yellow}INFO${nc} ] Installing daily cleaner cron job..."

cat > "$CLEANER_SCRIPT" << 'EOF'
#!/bin/bash
# Trojan Trial Cleaner
CONFIG="/etc/xray/config.json"
TRIAL_DIR="/etc/trojan/trial"
LOG="/var/log/trojan-cleaner.log"

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
    echo "$(date): Removing expired Trojan user: $user (Expired: $exp)" >> "$LOG"
    
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

# --- Add cron job (daily at 00:05) ---
(crontab -l 2>/dev/null | grep -v "trojan-cleaner"; echo "5 0 * * * $CLEANER_SCRIPT >/dev/null 2>&1") | crontab -

# --- Kembali ke menu ---
read -n 1 -s -r -p "Press any key to return to menu..."
return_to_menu