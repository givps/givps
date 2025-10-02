#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For VPN (Trojan) on Debian & Ubuntu
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
nc='\e[0m'        # No Color (reset)

# --- Get Server IP ---
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# --- Domain & Ports ---
domain=$(cat /etc/xray/domain)
tls=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')
none=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')

# --- Generate Trial Trojan User ---
user="trial$(tr -dc 'A-Z0-9' </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
expired=1
exp=$(date -d "${expired} days" +"%Y-%m-%d")

# --- Add User to Xray Config (requires markers #trojanws & #trojangrpc) ---
sed -i '/#trojanws$/a\#! '"${user} ${exp}"'\
},{"password": "'"${uuid}"'","email": "'"${user}"'"}' /etc/xray/config.json

sed -i '/#trojangrpc$/a\#! '"${user} ${exp}"'\
},{"password": "'"${uuid}"'","email": "'"${user}"'"}' /etc/xray/config.json

# --- Restart Services ---
systemctl restart xray >/dev/null 2>&1 || true
service cron restart >/dev/null 2>&1 || true

# --- Build Trojan Links ---
trojanlink_tls="trojan://${uuid}@${domain}:${tls}?path=%2Ftrojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
trojanlink_none="trojan://${uuid}@${domain}:${none}?path=%2Ftrojan&security=none&host=${domain}&type=ws#${user}"
trojanlink_grpc="trojan://${uuid}@${domain}:${tls}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

# --- Save Trial Info ---
mkdir -p /etc/trojan/trial
echo "${exp}" > /etc/trojan/trial/${user}.conf
echo "Trojan Trial: ${user} | Exp: ${exp}" >> /etc/log-create-user.log

# --- Setup Auto Cleaner Script ---
cat > /usr/local/bin/trojan-cleaner <<'EOF'
#!/bin/bash
today=$(date +%Y-%m-%d)
config="/etc/xray/config.json"

for file in /etc/trojan/trial/*.conf; do
    [ -e "$file" ] || continue
    user=$(basename "$file" .conf)
    exp=$(cat "$file")
    if [[ $(date -d "$exp" +%s) -le $(date -d "$today" +%s) ]]; then
        # Remove expired user from config
        sed -i "/#! $user $exp/,/},/d" "$config"
        rm -f "$file"
        echo "Expired Trojan user $user removed on $today" >> /var/log/trojan-cleaner.log
    fi
done

systemctl restart xray >/dev/null 2>&1
EOF

chmod +x /usr/local/bin/trojan-cleaner

# --- Add Cron Job (if not exists) ---
if ! crontab -l | grep -q "trojan-cleaner"; then
    (crontab -l 2>/dev/null; echo "5 0 * * * /usr/local/bin/trojan-cleaner") | crontab -
fi

# --- Output Account Information ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}           TRIAL TROJAN ACCOUNT          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks        : ${user}"
echo -e "Host / Domain  : ${domain}"
echo -e "Wildcard Bug   : bug.com.${domain}"
echo -e "Port TLS       : ${tls}"
echo -e "Port none TLS  : ${none}"
echo -e "Port gRPC      : ${tls}"
echo -e "Password (UUID): ${uuid}"
echo -e "Path           : /trojan"
echo -e "Service Name   : trojan-grpc"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS       : ${trojanlink_tls}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS  : ${trojanlink_none}"
echo -e "${red}=========================================${nc}"
echo -e "Link gRPC      : ${trojanlink_grpc}"
echo -e "${red}=========================================${nc}"
echo -e "Expired On     : ${exp}"
echo -e "${red}=========================================${nc}"
echo ""
read -n 1 -s -r -p "Press any key to return to menu"
sleep 1
m-trojan
