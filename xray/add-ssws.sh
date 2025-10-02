#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For Creating VPN on Debian & Ubuntu Server
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
tls="$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')"
none="$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')"

# =========================================
# Input User
CLIENT_EXISTS=1
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Add Shadowsocks Account        ${nc}"
    echo -e "${red}=========================================${nc}"
    read -rp "Username: " -e user
    CLIENT_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)

    if [[ ${CLIENT_EXISTS} == '1' ]]; then
        clear
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}          Add Shadowsocks Account        ${nc}"
        echo -e "${red}=========================================${nc}"
        echo ""
        echo "A client with this username already exists. Please choose another username."
        echo ""
        echo -e "${red}=========================================${nc}"
        read -n 1 -s -r -p "Press any key to return to menu..."
        m-ssws
    fi
done

# =========================================
# Account configuration
cipher="aes-128-gcm"
uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "Expired (days): " expired
exp=$(date -d "$expired days" +"%Y-%m-%d")

# Add user to config
sed -i '/#ssws$/a\### '"$user $exp"'\
},{"password": "'"$uuid"'","method": "'"$cipher"'","email": "'"$user"'"}' /etc/xray/config.json
sed -i '/#ssgrpc$/a\### '"$user $exp"'\
},{"password": "'"$uuid"'","method": "'"$cipher"'","email": "'"$user"'"}' /etc/xray/config.json

# Save to user database
echo "$user $exp" >> /etc/xray/ss-user

# =========================================
# Generate Links
echo $cipher:$uuid > /tmp/log
shadowsocks_base64=$(cat /tmp/log)
echo -n "${shadowsocks_base64}" | base64 > /tmp/log1
shadowsocks_base64e=$(cat /tmp/log1)
rm -f /tmp/log /tmp/log1

shadowsockslink="ss://${shadowsocks_base64e}@bug.com:$tls?path=ss-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
shadowsockslink1="ss://${shadowsocks_base64e}@bug.com:$none?path=ss-ws&security=none&host=${domain}&type=ws#${user}"
shadowsockslink2="ss://${shadowsocks_base64e}@${domain}:$tls?mode=gun&security=tls&type=grpc&serviceName=ss-grpc&sni=bug.com#${user}"

systemctl restart xray

# =========================================
# Create client config file
cat > /home/vps/public_html/ss-$user.txt <<-END
{
  "remarks": "$user",
  "address": "$domain",
  "port_tls": "$tls",
  "port_none_tls": "$none",
  "port_grpc": "$tls",
  "password": "$uuid",
  "method": "$cipher",
  "network": "ws/grpc",
  "path": "/ss-ws",
  "serviceName": "ss-grpc",
  "link_tls": "$shadowsockslink",
  "link_none_tls": "$shadowsockslink1",
  "link_grpc": "$shadowsockslink2",
  "expired_on": "$exp"
}
END

systemctl restart xray > /dev/null 2>&1
service cron restart > /dev/null 2>&1

# =========================================
# Output Account Info
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${blue}           Shadowsocks Account           ${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Username       : ${user}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Domain         : ${domain}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Wildcard       : bug.com.${domain}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Port TLS       : ${tls}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Port None TLS  : ${none}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Port gRPC      : ${tls}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Password       : ${uuid}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Cipher         : ${cipher}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Network        : ws/grpc" | tee -a /etc/log-create-shadowsocks.log
echo -e "Path           : /ss-ws" | tee -a /etc/log-create-shadowsocks.log
echo -e "Service Name   : ss-grpc" | tee -a /etc/log-create-shadowsocks.log
echo -e "Link TLS       : ${shadowsockslink}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Link None TLS  : ${shadowsockslink1}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Link gRPC      : ${shadowsockslink2}" | tee -a /etc/log-create-shadowsocks.log
echo -e "Expired On     : $exp" | tee -a /etc/log-create-shadowsocks.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-shadowsocks.log

# =========================================
# Auto Expired Script
cat > /usr/local/bin/xray-cleaner <<'EOF'
#!/bin/bash
today=$(date +%Y-%m-%d)
config="/etc/xray/config.json"
db="/etc/xray/ss-user"

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

chmod +x /usr/local/bin/xray-cleaner

# =========================================
# Create cron job if not exists
if [[ ! -f /etc/cron.d/xray-cleaner ]]; then
cat > /etc/cron.d/xray-cleaner <<EOF
0 0 * * * root /usr/local/bin/xray-cleaner >/dev/null 2>&1
EOF
fi

read -n 1 -s -r -p "Press any key to return to menu..."
m-ssws
