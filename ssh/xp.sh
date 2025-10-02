#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS to Create VPN on Debian & Ubuntu Server
# Version : 1.0
# Author  : gilper0x
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

LOG_FILE="/var/log/autoremove.log"
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo "[$(date)] Starting auto-remove process on VPS $MYIP" | tee -a $LOG_FILE
clear
now=$(date +"%Y-%m-%d")

# ============= Auto Remove Vmess =============
users_vmess=$(grep '^### ' /etc/xray/config.json | awk '{print $2}' | sort -u)
for user in $users_vmess; do
    exp=$(grep -w "^### $user" /etc/xray/config.json | awk '{print $3}')
    [[ -z "$exp" ]] && continue
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    days_left=$(( (d1 - d2) / 86400 ))
    if [[ $days_left -le 0 ]]; then
        sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
        rm -f /etc/xray/$user-tls.json /etc/xray/$user-none.json
        echo "[$(date)] Removed expired Vmess user: $user (expired $exp)" | tee -a $LOG_FILE
    fi
done

# ============= Auto Remove Vless =============
users_vless=$(grep '^#& ' /etc/xray/config.json | awk '{print $2}' | sort -u)
for user in $users_vless; do
    exp=$(grep -w "^#& $user" /etc/xray/config.json | awk '{print $3}')
    [[ -z "$exp" ]] && continue
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    days_left=$(( (d1 - d2) / 86400 ))
    if [[ $days_left -le 0 ]]; then
        sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
        echo "[$(date)] Removed expired Vless user: $user (expired $exp)" | tee -a $LOG_FILE
    fi
done

# ============= Auto Remove Trojan =============
users_trojan=$(grep '^#! ' /etc/xray/config.json | awk '{print $2}' | sort -u)
for user in $users_trojan; do
    exp=$(grep -w "^#! $user" /etc/xray/config.json | awk '{print $3}')
    [[ -z "$exp" ]] && continue
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    days_left=$(( (d1 - d2) / 86400 ))
    if [[ $days_left -le 0 ]]; then
        sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
        echo "[$(date)] Removed expired Trojan user: $user (expired $exp)" | tee -a $LOG_FILE
    fi
done

# Restart Xray after modifications
systemctl restart xray
echo "[$(date)] Restarted Xray service" | tee -a $LOG_FILE

# ============= Auto Remove SSH Users =============
today=$(date +%s)
while IFS=: read -r username _ _ _ _ _ _ expire; do
    [[ -z "$expire" || "$expire" == "" ]] && continue
    expire_seconds=$((expire * 86400))
    if [[ $expire_seconds -lt $today ]]; then
        userdel --force "$username" 2>/dev/null
        echo "[$(date)] Removed expired SSH user: $username" | tee -a $LOG_FILE
    fi
done < /etc/shadow

echo "[$(date)] Auto-remove process completed." | tee -a $LOG_FILE
