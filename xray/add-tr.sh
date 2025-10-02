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

# =========================================
# Get VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Load configuration
source /var/lib/ipvps.conf
if [[ "$IP" == "" ]]; then
  domain=$(cat /etc/xray/domain)
else
  domain=$IP
fi

# Extract ports
tls=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')
none=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')

# =========================================
# Create new Trojan user
user_EXISTS=1
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             TROJAN ACCOUNT              ${nc}"
    echo -e "${red}=========================================${nc}"
    read -rp "Enter Username: " -e user
    user_EXISTS=$(grep -w "$user" /etc/xray/config.json | wc -l)

    if [[ ${user_EXISTS} == '1' ]]; then
        clear
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}             TROJAN ACCOUNT              ${nc}"
        echo -e "${red}=========================================${nc}"
        echo ""
        echo "A client with this name already exists. Please choose another username."
        echo ""
        echo -e "${red}=========================================${nc}"
        read -n 1 -s -r -p "Press any key to return to menu..."
        m-trojan
    fi
done

uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "Expired (days): " expired
exp=$(date -d "$expired days" +"%Y-%m-%d")

# Add user to config.json
sed -i '/#trojanws$/a\### '"$user $exp"'\
},{"password": "'"$uuid"'","email": "'"$user"'"}' /etc/xray/config.json
sed -i '/#trojangrpc$/a\### '"$user $exp"'\
},{"password": "'"$uuid"'","email": "'"$user"'"}' /etc/xray/config.json

# Save to user database
echo "$user $exp" >> /etc/xray/trojan-user

# Generate links
trojanlink="trojan://${uuid}@bug.com:${tls}?path=%2Ftrojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
trojanlink2="trojan://${uuid}@bug.com:${none}?path=%2Ftrojan&security=none&host=${domain}&type=ws#${user}"
trojanlink1="trojan://${uuid}@${domain}:${tls}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=bug.com#${user}"

systemctl restart xray

# =========================================
# Display account information
clear
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-trojan.log
echo -e "${blue}             TROJAN ACCOUNT              ${nc}" | tee -a /etc/log-create-trojan.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-trojan.log
echo -e "Username       : ${user}" | tee -a /etc/log-create-trojan.log
echo -e "Host/IP        : ${domain}" | tee -a /etc/log-create-trojan.log
echo -e "Wildcard       : bug.com.${domain}" | tee -a /etc/log-create-trojan.log
echo -e "Port TLS       : ${tls}" | tee -a /etc/log-create-trojan.log
echo -e "Port None TLS  : ${none}" | tee -a /etc/log-create-trojan.log
echo -e "Port gRPC      : ${tls}" | tee -a /etc/log-create-trojan.log
echo -e "Key (UUID)     : ${uuid}" | tee -a /etc/log-create-trojan.log
echo -e "Network        : ws/grpc" | tee -a /etc/log-create-trojan.log
echo -e "Path           : /trojan" | tee -a /etc/log-create-trojan.log
echo -e "Service Name   : trojan-grpc" | tee -a /etc/log-create-trojan.log
echo -e "Link TLS       : ${trojanlink}" | tee -a /etc/log-create-trojan.log
echo -e "Link None TLS  : ${trojanlink2}" | tee -a /etc/log-create-trojan.log
echo -e "Link gRPC      : ${trojanlink1}" | tee -a /etc/log-create-trojan.log
echo -e "Expired On     : $exp" | tee -a /etc/log-create-trojan.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-trojan.log
echo "" | tee -a /etc/log-create-trojan.log

# =========================================
# Auto Expired Script
cat > /usr/local/bin/trojan-cleaner <<'EOF'
#!/bin/bash
today=$(date +%Y-%m-%d)
config="/etc/xray/config.json"
db="/etc/xray/trojan-user"

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

chmod +x /usr/local/bin/trojan-cleaner

# Create cron job for auto cleanup
if [[ ! -f /etc/cron.d/trojan-cleaner ]]; then
cat > /etc/cron.d/trojan-cleaner <<EOF
0 0 * * * root /usr/local/bin/trojan-cleaner >/dev/null 2>&1
EOF
fi

read -n 1 -s -r -p "Press any key to return to menu..."
m-trojan
