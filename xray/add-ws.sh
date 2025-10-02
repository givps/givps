#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS to Create VPN on Debian & Ubuntu Server
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
nc='\e[0m'        # Reset color

# Detect VPS IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Load saved domain/IP config
source /var/lib/ipvps.conf
if [[ -z "$IP" ]]; then
    domain=$(cat /etc/xray/domain)
else
    domain=$IP
fi

tls="$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')"
none="$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | sed 's/ //g')"

# Create new user
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Add VMess Account              ${nc}"
    echo -e "${red}=========================================${nc}"
    read -rp "Username: " -e user
    CLIENT_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)

    if [[ ${CLIENT_EXISTS} == '1' ]]; then
        clear
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}          Add VMess Account              ${nc}"
        echo -e "${red}=========================================${nc}"
        echo ""
        echo "Error: A client with this username already exists. Please choose another name."
        echo ""
        echo -e "${red}=========================================${nc}"
        read -n 1 -s -r -p "Press any key to return to menu"
        m-vmess
    fi
done

uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "Expired (days): " expired
exp=$(date -d "$expired days" +"%Y-%m-%d")

# Add user to config.json
sed -i '/#vmess$/a\### '"$user $exp"'\
},{"id": "'$uuid'","alterId": 0,"email": "'$user'"' /etc/xray/config.json
sed -i '/#vmessgrpc$/a\### '"$user $exp"'\
},{"id": "'$uuid'","alterId": 0,"email": "'$user'"' /etc/xray/config.json

# Save user to database
echo "$user $exp" >> /etc/xray/vmess-user

# Ensure auto-cleaner is installed
if [[ ! -f /usr/local/bin/vmess-cleaner ]]; then
cat > /usr/local/bin/vmess-cleaner <<'EOF'
#!/bin/bash
# Auto remove expired VMess users from Xray
config="/etc/xray/config.json"
db="/etc/xray/vmess-user"
today=$(date +%Y-%m-%d)

[[ ! -f $db ]] && exit 0

while read -r user exp; do
  if [[ $(date -d "$exp" +%s) -lt $(date -d "$today" +%s) ]]; then
    echo "Removing expired user: $user ($exp)"
    sed -i "/^### $user $exp/,/},/d" $config
    sed -i "/$user $exp/d" $db
  fi
done < $db

systemctl restart xray
EOF
chmod +x /usr/local/bin/vmess-cleaner

# Cronjob
cat > /etc/cron.d/vmess-cleaner <<EOF
0 0 * * * root /usr/local/bin/vmess-cleaner >/dev/null 2>&1
EOF
fi

# Generate VMess configs
wstls=$(cat<<EOF
{
"v": "2",
"ps": "${user}",
"add": "${domain}",
"port": "443",
"id": "${uuid}",
"aid": "0",
"net": "ws",
"path": "/vmess",
"type": "none",
"host": "",
"tls": "tls"
}
EOF
)

wsnontls=$(cat<<EOF
{
"v": "2",
"ps": "${user}",
"add": "${domain}",
"port": "80",
"id": "${uuid}",
"aid": "0",
"net": "ws",
"path": "/vmess",
"type": "none",
"host": "",
"tls": "none"
}
EOF
)

grpc=$(cat<<EOF
{
"v": "2",
"ps": "${user}",
"add": "${domain}",
"port": "443",
"id": "${uuid}",
"aid": "0",
"net": "grpc",
"path": "vmess-grpc",
"type": "none",
"host": "",
"tls": "tls"
}
EOF
)

vmesslink1="vmess://$(echo $wstls | base64 -w 0)"
vmesslink2="vmess://$(echo $wsnontls | base64 -w 0)"
vmesslink3="vmess://$(echo $grpc | base64 -w 0)"

systemctl restart xray >/dev/null 2>&1
service cron restart >/dev/null 2>&1

# Show account details
clear
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vmess.log
echo -e "${blue}           VMess Account                 ${nc}" | tee -a /etc/log-create-vmess.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vmess.log
echo -e "Username       : ${user}" | tee -a /etc/log-create-vmess.log
echo -e "Domain         : ${domain}" | tee -a /etc/log-create-vmess.log
echo -e "Wildcard       : bug.com.${domain}" | tee -a /etc/log-create-vmess.log
echo -e "Port TLS       : ${tls}" | tee -a /etc/log-create-vmess.log
echo -e "Port none TLS  : ${none}" | tee -a /etc/log-create-vmess.log
echo -e "Port gRPC      : ${tls}" | tee -a /etc/log-create-vmess.log
echo -e "UUID           : ${uuid}" | tee -a /etc/log-create-vmess.log
echo -e "alterId        : 0" | tee -a /etc/log-create-vmess.log
echo -e "Security       : auto" | tee -a /etc/log-create-vmess.log
echo -e "Network        : ws/grpc" | tee -a /etc/log-create-vmess.log
echo -e "Path           : /vmess" | tee -a /etc/log-create-vmess.log
echo -e "ServiceName    : vmess-grpc" | tee -a /etc/log-create-vmess.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vmess.log
echo -e "Link TLS       : ${vmesslink1}" | tee -a /etc/log-create-vmess.log
echo -e "Link none TLS  : ${vmesslink2}" | tee -a /etc/log-create-vmess.log
echo -e "Link gRPC      : ${vmesslink3}" | tee -a /etc/log-create-vmess.log
echo -e "Expired On     : $exp" | tee -a /etc/log-create-vmess.log
echo -e "${red}=========================================${nc}" | tee -a /etc/log-create-vmess.log
echo "" | tee -a /etc/log-create-vmess.log
read -n 1 -s -r -p "Press any key to return to menu"

m-vmess
