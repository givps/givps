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

# Get Server IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# Check whether XRAY or V2RAY is used
cekray=$(grep -ow "XRAY" /root/log-install.txt | sort | uniq)
if [ "$cekray" = "XRAY" ]; then
  old_domain=$(cat /etc/xray/domain)
else
  old_domain=$(cat /etc/v2ray/domain)
fi

clear
echo -e "[ ${green}INFO${nc} ] Starting..."
sleep 0.5
systemctl stop nginx
domain=$(cat /var/lib/ipvps.conf | cut -d'=' -f2)

# Check if port 80 is in use
Cek=$(lsof -i:80 | awk 'NR==2 {print $1}')
if [[ ! -z "$Cek" ]]; then
  echo -e "[ ${red}WARNING${nc} ] Port 80 detected in use by $Cek "
  systemctl stop $Cek
  sleep 1
  echo -e "[ ${green}INFO${nc} ] Stopped $Cek "
fi

# Issue certificate
echo -e "[ ${green}INFO${nc} ] Starting certificate renewal... "
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $domain \
  --fullchainpath /etc/xray/xray.crt \
  --keypath /etc/xray/xray.key --ecc

if [[ $? -eq 0 ]]; then
  echo -e "[ ${green}INFO${nc} ] Certificate renewed successfully "
else
  echo -e "[ ${red}ERROR${nc} ] Failed to renew certificate!"
  exit 1
fi

# Save domain
echo $domain > /etc/xray/domain
echo $domain > /etc/v2ray/domain

# Restart services
systemctl restart $Cek 2>/dev/null
systemctl restart nginx
systemctl restart xray 2>/dev/null
systemctl restart v2ray 2>/dev/null

echo -e "[ ${green}INFO${nc} ] All processes finished "
sleep 0.5

# Setup auto-renew via cron
cat > /usr/local/bin/renew-cert.sh << 'EOF'
#!/bin/bash
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /etc/v2ray/domain 2>/dev/null)
if [[ -z "\$DOMAIN" ]]; then
  echo "Domain not found!"
  exit 1
fi

CERT_FILE="/etc/xray/xray.crt"
if [[ -f "\$CERT_FILE" ]]; then
  end_date=\$(openssl x509 -enddate -noout -in "\$CERT_FILE" | cut -d= -f2)
  end_sec=\$(date -d "\$end_date" +%s)
  now_sec=\$(date +%s)
  days_left=\$(( (end_sec - now_sec) / 86400 ))
else
  days_left=0
fi

if [[ \$days_left -le 5 ]]; then
  echo "\$(date) - Certificate will expire in \$days_left days. Renewing..." >> /var/log/renew-cert.log
  /root/.acme.sh/acme.sh --renew -d "\$DOMAIN" --force --ecc \
    --fullchainpath /etc/xray/xray.crt \
    --keypath /etc/xray/xray.key
  if [[ \$? -eq 0 ]]; then
    echo "\$(date) - Certificate renewed successfully for \$DOMAIN" >> /var/log/renew-cert.log
    systemctl restart nginx
    systemctl restart xray 2>/dev/null
    systemctl restart v2ray 2>/dev/null
  else
    echo "\$(date) - Failed to renew certificate for \$DOMAIN" >> /var/log/renew-cert.log
  fi
else
  echo "\$(date) - Certificate still valid for \$days_left days, no renewal needed" >> /var/log/renew-cert.log
fi
EOF

chmod +x /usr/local/bin/renew-cert.sh

# Add cron job (avoid duplicates)
crontab -l 2>/dev/null | grep -v "renew-cert.sh" | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/renew-cert.sh >/dev/null 2>&1") | crontab -

echo -e "[ ${green}INFO${nc} ] Auto-renew cron job has been created (schedule: daily at 3 AM)"
echo ""
read -n 1 -s -r -p "Press any key to return to menu"
m-domain
