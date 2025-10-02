#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS for Creating VPN on Debian & Ubuntu Server
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

# Get VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Load config
source /var/lib/ipvps.conf
if [[ -z "$IP" ]]; then
  domain=$(cat /etc/xray/domain)
else
  domain=$IP
fi

tls=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')
none=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')

# ==========================================
# Input new user
CLIENT_EXISTS=1
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Add VLESS Account              ${nc}"
    echo -e "${red}=========================================${nc}"
    read -rp "Username: " -e user
    CLIENT_EXISTS=$(grep -w "$user" /etc/xray/config.json | wc -l)

    if [[ ${CLIENT_EXISTS} == '1' ]]; then
        clear
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}          Add VLESS Account              ${nc}"
        echo -e "${red}=========================================${nc}"
        echo ""
        echo "A client with this username already exists. Please choose another one."
        echo ""
        read -n 1 -s -r -p "Press any key to return to the menu..."
        m-vless
    fi
done

# ==========================================
# Generate UUID & Expiration
uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "Expired (days): " expired
exp=$(date -d "$expired days" +"%Y-%m-%d")

# Add user into config.json
sed -i '/#vless$/a\### '"$user $exp"'\
},{"id": "'"$uuid"'","email": "'"$user"'"}' /etc/xray/config.json

sed -i '/#vlessgrpc$/a\### '"$user $exp"'\
},{"id": "'"$uuid"'","email": "'"$user"'"}' /etc/xray/config.json

# Save user to database
echo "$user $exp" >> /etc/xray/vless-user

# ==========================================
# Generate VLESS links
vlesslink1="vless://${uuid}@${domain}:${tls}?path=/vless&security=tls&encryption=none&type=ws&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:${none}?path=/vless&encryption=none&type=ws#${user}"
vlesslink3="vless://${uuid}@${domain}:${tls}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"

systemctl restart xray

# ==========================================
# Output Account Info
clear
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vless.log
echo -e "${blue}            VLESS Account Info           ${nc}" | tee -a /etc/log-create-vless.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vless.log
echo -e "Username       : ${user}" | tee -a /etc/log-create-vless.log
echo -e "Domain         : ${domain}" | tee -a /etc/log-create-vless.log
echo -e "Wildcard       : bug.com.${domain}" | tee -a /etc/log-create-vless.log
echo -e "Port TLS       : $tls" | tee -a /etc/log-create-vless.log
echo -e "Port non-TLS   : $none" | tee -a /etc/log-create-vless.log
echo -e "UUID           : ${uuid}" | tee -a /etc/log-create-vless.log
echo -e "Encryption     : none" | tee -a /etc/log-create-vless.log
echo -e "Network        : ws/grpc" | tee -a /etc/log-create-vless.log
echo -e "Path (WS)      : /vless" | tee -a /etc/log-create-vless.log
echo -e "ServiceName    : vless-grpc" | tee -a /etc/log-create-vless.log
echo -e "VLESS TLS      : ${vlesslink1}" | tee -a /etc/log-create-vless.log
echo -e "VLESS non-TLS  : ${vlesslink2}" | tee -a /etc/log-create-vless.log
echo -e "VLESS gRPC     : ${vlesslink3}" | tee -a /etc/log-create-vless.log
echo -e "Expired On     : $exp" | tee -a /etc/log-create-vless.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vless.log
echo "" | tee -a /etc/log-create-vless.log

# ==========================================
# Auto Cleaner Script for Expired Accounts
cat > /usr/local/bin/vless-cleaner <<'EOF'
#!/bin/bash
today=$(date +%Y-%m-%d)
config="/etc/xray/config.json"
db="/etc/xray/vless-user"

[[ ! -f $db ]] && exit 0

while read -r user exp; do
  if [[ $(date -d "$exp" +%s) -lt $(date -d "$today" +%s) ]]; then
    echo "User $user expired on $exp, removing..."
    sed -i "/^### $user $exp/,/},/d" $config
    sed -i "/$user $exp/d" $db
  fi
done < $db

systemctl restart xray
EOF

chmod +x /usr/local/bin/vless-cleaner

# Create cron job if it doesn’t exist
if [[ ! -f /etc/cron.d/vless-cleaner ]]; then
cat > /etc/cron.d/vless-cleaner <<EOF
0 0 * * * root /usr/local/bin/vless-cleaner >/dev/null 2>&1
EOF
fi

read -n 1 -s -r -p "Press any key to return to the menu..."
m-vless
