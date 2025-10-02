#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For VPN (Shadowsocks) on Debian & Ubuntu
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

# --- Get VPS IP ---
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# --- Domain & Ports ---
domain=$(cat /etc/xray/domain)
tls=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')
none=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')

# === Expired User Auto-Cleaner ===
clean_expired() {
    today=$(date +"%Y-%m-%d")
    for file in /etc/shadowsocks/trial/*.conf; do
        [ -e "$file" ] || continue
        user=$(basename "$file" .conf)
        exp=$(cat "$file")
        if [[ "$today" > "$exp" ]]; then
            sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
            rm -f "$file"
            echo "Removed expired user: $user"
        fi
    done
    systemctl restart xray
}

# --- Clean expired users first ---
mkdir -p /etc/shadowsocks/trial
clean_expired

# === Generate New Trial User ===
user=trial$(tr -dc 'A-Z0-9' </dev/urandom | head -c4)
cipher="aes-128-gcm"
uuid=$(cat /proc/sys/kernel/random/uuid)
expired=1
exp=$(date -d "$expired days" +"%Y-%m-%d")

# --- Add User to Xray Config ---
sed -i '/#ssws$/a\### '"$user $exp"'\
},{"password": "'"$uuid"'","method": "'"$cipher"'","email": "'"$user"'"' /etc/xray/config.json

sed -i '/#ssgrpc$/a\### '"$user $exp"'\
},{"password": "'"$uuid"'","method": "'"$cipher"'","email": "'"$user"'"' /etc/xray/config.json

# --- Encode Shadowsocks ---
echo -n "$cipher:$uuid" | base64 > /tmp/ss-raw
ss_b64=$(cat /tmp/ss-raw)

# --- Build Shadowsocks Links ---
ss_link_tls="ss://${ss_b64}@${domain}:$tls?path=/ss-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
ss_link_none="ss://${ss_b64}@${domain}:$none?path=/ss-ws&security=none&host=${domain}&type=ws#${user}"
ss_link_grpc="ss://${ss_b64}@${domain}:$tls?mode=gun&security=tls&type=grpc&serviceName=ss-grpc&sni=${domain}#${user}"

# --- Restart Services ---
systemctl restart xray > /dev/null 2>&1
service cron restart > /dev/null 2>&1

# --- Output User Information ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}          SHADOWSOCKS TRIAL ACCOUNT      ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "Wildcard Bug   : bug.com.${domain}"
echo -e "Port TLS       : ${tls}"
echo -e "Port none TLS  : ${none}"
echo -e "Port gRPC      : ${tls}"
echo -e "Password       : ${uuid}"
echo -e "Cipher         : ${cipher}"
echo -e "Network        : ws / grpc"
echo -e "Path (WS)      : /ss-ws"
echo -e "Service Name   : ss-grpc"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS       : ${ss_link_tls}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS  : ${ss_link_none}"
echo -e "${red}=========================================${nc}"
echo -e "Link gRPC      : ${ss_link_grpc}"
echo -e "${red}=========================================${nc}"
echo -e "Expired On     : $exp"
echo -e "${red}=========================================${nc}"

# --- Save Logs & Expiration File ---
echo "Shadowsocks Trial: $user | Exp: $exp" >> /etc/log-create-user.log
echo "$exp" > /etc/shadowsocks/trial/${user}.conf

# --- Back to Menu ---
read -n 1 -s -r -p "Press any key to return to menu"
m-ssws
