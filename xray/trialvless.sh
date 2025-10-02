#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For Create VPN on Debian & Ubuntu Server
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

# Get VPS public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Get domain & ports
domain=$(cat /etc/xray/domain)
tls=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')
none=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')

# Generate trial VLESS user
user="trial$(tr -dc 'A-Z0-9' </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
expired=1
exp=$(date -d "$expired days" +"%Y-%m-%d")

# Add to Xray config (marker #vless & #vlessgrpc must exist in config.json)
sed -i '/#vless$/a\#! '"${user} ${exp}"'\
},{"id": "'"${uuid}"'","email": "'"${user}"'"}' /etc/xray/config.json

sed -i '/#vlessgrpc$/a\#! '"${user} ${exp}"'\
},{"id": "'"${uuid}"'","email": "'"${user}"'"}' /etc/xray/config.json

# Restart services
systemctl restart xray >/dev/null 2>&1
service cron restart >/dev/null 2>&1

# Create VLESS links
vlesslink1="vless://${uuid}@${domain}:${tls}?path=/vless&security=tls&encryption=none&type=ws&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:${none}?path=/vless&encryption=none&type=ws#${user}"
vlesslink3="vless://${uuid}@${domain}:${tls}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"

# Save trial info
mkdir -p /etc/vless/trial
echo "${exp}" > /etc/vless/trial/${user}.conf
echo "VLESS Trial: ${user} | Exp: ${exp}" >> /etc/log-create-user.log

# Auto-cleaner script
cat > /usr/local/bin/vless-cleaner <<'EOF'
#!/bin/bash
today=$(date +%Y-%m-%d)
config="/etc/xray/config.json"

for file in /etc/vless/trial/*.conf; do
    [ -e "$file" ] || continue
    user=$(basename "$file" .conf)
    exp=$(cat "$file")
    if [[ $(date -d "$exp" +%s) -le $(date -d "$today" +%s) ]]; then
        sed -i "/#! $user $exp/,/},/d" "$config"
        rm -f "$file"
        echo "Expired VLESS user $user removed on $today" >> /var/log/vless-cleaner.log
    fi
done

systemctl restart xray >/dev/null 2>&1
EOF

chmod +x /usr/local/bin/vless-cleaner

# Add cron job if not exists
if ! crontab -l | grep -q "vless-cleaner"; then
    (crontab -l 2>/dev/null; echo "10 0 * * * /usr/local/bin/vless-cleaner") | crontab -
fi

# Display account info
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}        TRIAL VLESS ACCOUNT        ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks          : ${user}"
echo -e "Domain           : ${domain}"
echo -e "Wildcard         : bug.com.${domain}"
echo -e "Port TLS         : ${tls}"
echo -e "Port none TLS    : ${none}"
echo -e "Port gRPC        : ${tls}"
echo -e "ID               : ${uuid}"
echo -e "Encryption       : none"
echo -e "Network          : ws / grpc"
echo -e "Path WS          : /vless"
echo -e "ServiceName gRPC : vless-grpc"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS         : ${vlesslink1}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS    : ${vlesslink2}"
echo -e "${red}=========================================${nc}"
echo -e "Link gRPC        : ${vlesslink3}"
echo -e "${red}=========================================${nc}"
echo -e "Expired On       : ${exp}"
echo -e "${red}=========================================${nc}"
echo ""
read -n 1 -s -r -p "Press any key to return to menu"
m-vless
