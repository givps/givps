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

# Generate trial user
user="trial$(tr -dc 'A-Z0-9' </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
expired=1
exp=$(date -d "$expired days" +"%Y-%m-%d")

# Insert user into config.json
sed -i '/#vmess$/a\### '"${user} ${exp}"'\
},{"id": "'"${uuid}"'","alterId": 0,"email": "'"${user}"'"}' /etc/xray/config.json

sed -i '/#vmessgrpc$/a\### '"${user} ${exp}"'\
},{"id": "'"${uuid}"'","alterId": 0,"email": "'"${user}"'"}' /etc/xray/config.json

# Restart services
systemctl restart xray >/dev/null 2>&1
service cron restart >/dev/null 2>&1

# Create JSON links
wstls=$(cat <<EOF
{
  "v": "2",
  "ps": "${user}",
  "add": "${domain}",
  "port": "${tls}",
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

wsnontls=$(cat <<EOF
{
  "v": "2",
  "ps": "${user}",
  "add": "${domain}",
  "port": "${none}",
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

grpc=$(cat <<EOF
{
  "v": "2",
  "ps": "${user}",
  "add": "${domain}",
  "port": "${tls}",
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

# Encode to base64
vmesslink1="vmess://$(echo "$wstls" | base64 -w 0)"
vmesslink2="vmess://$(echo "$wsnontls" | base64 -w 0)"
vmesslink3="vmess://$(echo "$grpc" | base64 -w 0)"

# Display result
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}          Trial Vmess Account          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "Wildcard       : bug.com.${domain}"
echo -e "Port TLS       : ${tls}"
echo -e "Port none TLS  : ${none}"
echo -e "Port gRPC      : ${tls}"
echo -e "ID             : ${uuid}"
echo -e "alterId        : 0"
echo -e "Security       : auto"
echo -e "Network        : ws / grpc"
echo -e "Path WS        : /vmess"
echo -e "ServiceName    : vmess-grpc"
echo -e "${red}=========================================${nc}"
echo -e "Link TLS       : ${vmesslink1}"
echo -e "${red}=========================================${nc}"
echo -e "Link none TLS  : ${vmesslink2}"
echo -e "${red}=========================================${nc}"
echo -e "Link gRPC      : ${vmesslink3}"
echo -e "${red}=========================================${nc}"
echo -e "Expired On     : $exp"
echo -e "${red}=========================================${nc}"
echo ""

# Auto-cleaner setup
cat >/usr/local/bin/xray-cleaner <<'EOL'
#!/bin/bash
today=$(date +%s)
config="/etc/xray/config.json"

while read -r line; do
    if [[ $line == "### "* ]]; then
        user=$(echo $line | cut -d ' ' -f 2)
        exp=$(echo $line | cut -d ' ' -f 3)
        exp_ts=$(date -d "$exp" +%s)
        if [[ $exp_ts -le $today ]]; then
            # Remove expired users
            sed -i "/^### $user $exp/,/^},{/d" $config
            echo "Expired user removed: $user ($exp)"
        fi
    fi
done < <(grep '^### ' $config)

systemctl restart xray >/dev/null 2>&1
EOL

chmod +x /usr/local/bin/xray-cleaner

# Add cron job if not already exists
if ! crontab -l | grep -q "xray-cleaner"; then
    echo "*/30 * * * * /usr/local/bin/xray-cleaner >/dev/null 2>&1" >> /etc/cron.d/xray-cleaner
fi

read -n 1 -s -r -p "Press any key to return to menu"
m-vmess
