#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For Create VPN on Debian & Ubuntu Server
# Version : 1.3 (Final Revision)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # No Color (reset)

# Getting Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com);

# --- 1. Validasi Domain ---
echo -e "${green}Checking VPS...${nc}"

# Asumsi domain sudah ada di /etc/xray/domain dari script sebelumnya
if [ ! -f "/etc/xray/domain" ]; then
    echo -e "${red}ERROR:${nc} File /etc/xray/domain tidak ditemukan. Domain harus ada untuk instalasi SSL."
    echo "Harap pastikan domain Anda telah disiapkan."
    exit 1
fi

DOMAIN=$(cat /etc/xray/domain | tr -d '\n')
echo "$DOMAIN" > /root/domain
sleep 1
clear

# --- 2. Persiapan Sistem & Dependencies ---
echo -e "[ ${green}INFO${nc} ] Updating and installing dependencies..."

# Stop services jika sudah berjalan
systemctl stop nginx 2>/dev/null
systemctl stop xray 2>/dev/null

# Install dependencies dasar
apt update -y
apt install -y iptables iptables-persistent jq curl socat xz-utils wget apt-transport-https gnupg dnsutils lsb-release cron bash-completion chrony zip openssl netcat

# Setting Waktu & NTP (Menggunakan chrony)
echo -e "[ ${green}INFO${nc} ] Setting NTP (chrony)..."
ntpdate pool.ntp.org 
timedatectl set-ntp true
systemctl enable chrony
systemctl restart chrony
timedatectl set-timezone Asia/Jakarta
sleep 1

# --- 3. Instalasi Xray Core ---
echo -e "[ ${green}INFO${nc} ] Downloading & Installing Xray core (v1.6.1)..."

# Persiapan direktori Xray
mkdir -p /var/log/xray
mkdir -p /etc/xray
mkdir -p /home/vps/public_html
chown www-data.www-data /var/log/xray /etc/xray
touch /var/log/xray/access.log /var/log/xray/error.log /var/log/xray/access2.log /var/log/xray/error2.log

# Instal Xray Core versi 1.6.1
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.6.1

# --- 4. SSL Certificate (acme.sh) ---
echo -e "[ ${green}INFO${nc} ] Generating SSL certificate using acme.sh..."

# Instalasi dan konfigurasi acme.sh
mkdir -p /root/.acme.sh
curl -s https://get.acme.sh | sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256

# Menginstal sertifikat ke lokasi Xray
~/.acme.sh/acme.sh --installcert -d $DOMAIN \
    --fullchainpath /etc/xray/xray.crt \
    --keypath /etc/xray/xray.key \
    --ecc

# Konfigurasi perpanjangan SSL otomatis via cron
echo '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l 2>/dev/null;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi

# --- 5. Xray Configuration File (/etc/xray/config.json) ---
UUID=$(cat /proc/sys/kernel/random/uuid)
echo -e "[ ${green}INFO${nc} ] Configuring Xray with UUID: $UUID"

# Xray config
cat > /etc/xray/config.json << END
{
  "log" : {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
      {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
   {
     "listen": "127.0.0.1",
     "port": 14016,
     "protocol": "vless",
      "settings": {
          "decryption":"none",
            "clients": [
               { "id": "${UUID}", "email": "vless-ws" }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": { "path": "/vless" }
        }
     },
     {
     "listen": "127.0.0.1",
     "port": 23456,
     "protocol": "vmess",
      "settings": {
            "clients": [
               { "id": "${UUID}", "alterId": 0, "email": "vmess-ws" }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": { "path": "/vmess" }
          }
     },
    {
      "listen": "127.0.0.1",
      "port": 25432,
      "protocol": "trojan",
      "settings": {
           "clients": [
              { "password": "${UUID}", "email": "trojan-ws" }
          ],
         "udp": true
       },
       "streamSettings":{
           "network": "ws",
           "wsSettings": { "path": "/trojan" }
         }
     },
    {
        "listen": "127.0.0.1",
        "port": 30300,
        "protocol": "shadowsocks",
        "settings": {
           "clients": [
             { "method": "aes-128-gcm", "password": "${UUID}", "email": "ss-ws" }
           ],
          "network": "tcp,udp"
       },
       "streamSettings":{
          "network": "ws",
             "wsSettings": { "path": "/ss-ws" }
        }
     },
      {
        "listen": "127.0.0.1",
        "port": 24456,
        "protocol": "vless",
        "settings": {
         "decryption":"none",
           "clients": [
             { "id": "${UUID}", "email": "vless-grpc" }
          ]
       },
          "streamSettings":{
             "network": "grpc",
             "grpcSettings": { "serviceName": "vless-grpc" }
        }
     },
     {
      "listen": "127.0.0.1",
      "port": 31234,
      "protocol": "vmess",
      "settings": {
            "clients": [
               { "id": "${UUID}", "alterId": 0, "email": "vmess-grpc" }
          ]
       },
       "streamSettings":{
         "network": "grpc",
            "grpcSettings": { "serviceName": "vmess-grpc" }
        }
     },
     {
        "listen": "127.0.0.1",
        "port": 33456,
        "protocol": "trojan",
        "settings": {
             "clients": [
               { "password": "${UUID}", "email": "trojan-grpc" }
           ]
        },
         "streamSettings":{
         "network": "grpc",
           "grpcSettings": { "serviceName": "trojan-grpc" }
      }
   },
   {
    "listen": "127.0.0.1",
    "port": 30310,
    "protocol": "shadowsocks",
    "settings": {
        "clients": [
          { "method": "aes-128-gcm", "password": "${UUID}", "email": "ss-grpc" }
         ],
           "network": "tcp,udp"
      },
    "streamSettings":{
     "network": "grpc",
        "grpcSettings": { "serviceName": "ss-grpc" }
       }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" },
    { "protocol": "blackhole", "tag": "blocked" }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","169.254.0.0/16",
          "172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16",
          "198.18.0.0/15","198.51.100.0/24","203.0.113.0/24",
          "::1/128","fc00::/7","fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": ["bittorrent"]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": ["StatsService"],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
END

# --- 6. Systemd Service Files ---
echo -e "[ ${green}INFO${nc} ] Configuring systemd services..."
rm -rf /etc/systemd/system/xray.service.d /etc/systemd/system/xray@.service /etc/systemd/system/runn.service

cat <<EOF> /etc/systemd/system/xray.service
Description=Xray Service
Documentation=https://github.com/xtls  
After=network.target nss-lookup.target

[Service]
User=www-data
# Mengurangi kemampuan yang diberikan (Minimal Access/Security Best Practice)
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# Menghapus runn.service (berlebihan dan tidak diperlukan)
# rm -f /etc/systemd/system/runn.service

# --- 7. Nginx Configuration File (/etc/nginx/conf.d/xray.conf) ---
echo -e "[ ${green}INFO${nc} ] Configuring Nginx proxy..."

cat >/etc/nginx/conf.d/xray.conf <<EOF
    server {
        listen 80;
        listen [::]:80;
        server_name $DOMAIN;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;
        server_name $DOMAIN;

        ssl_certificate /etc/xray/xray.crt;
        ssl_certificate_key /etc/xray/xray.key;
        ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;

        root /home/vps/public_html;
        
        # --- WebSocket Proxy ---
        location /vless {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:14016;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
        
        location /vmess {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:23456;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /trojan {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:25432;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /ss-ws {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:30300;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        # --- gRPC Proxy ---
        location ^~ /vless-grpc {
            grpc_pass grpc://127.0.0.1:24456;
        }
        
        location ^~ /vmess-grpc {
            grpc_pass grpc://127.0.0.1:31234;
        }
        
        location ^~ /trojan-grpc {
            grpc_pass grpc://127.0.0.1:33456;
        }
        
        location ^~ /ss-grpc {
            grpc_pass grpc://127.0.0.1:30310;
        }

        # --- Default Web/Fallback (Serving Static Files) ---
        location / {
             try_files \$uri \$uri/ =404; # Mengarahkan ke root jika tidak ada path yang cocok
        }
    }
EOF

# Menghapus konfigurasi Nginx default jika ada (praktik yang baik)
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# --- 8. Restart Services ---
echo -e "$yellow[SERVICE]$nc Restart All service"
systemctl daemon-reload
echo -e "[ ${green}ok${nc} ] Enable & restart Xray & Nginx"
systemctl enable xray
systemctl restart xray
systemctl enable nginx
systemctl restart nginx

# --- 9. Download Helper Scripts (Tidak Diubah) ---
echo -e "[ ${green}INFO${nc} ] Downloading helper scripts..."
cd /usr/bin/
# vmess
wget -O add-ws "https://raw.githubusercontent.com/givps/givps/master/xray/add-ws.sh" && chmod +x add-ws
wget -O trialvmess "https://raw.githubusercontent.com/givps/givps/master/xray/trialvmess.sh" && chmod +x trialvmess
wget -O renew-ws "https://raw.githubusercontent.com/givps/givps/master/xray/renew-ws.sh" && chmod +x renew-ws
wget -O del-ws "https://raw.githubusercontent.com/givps/givps/master/xray/del-ws.sh" && chmod +x del-ws
wget -O cek-ws "https://raw.githubusercontent.com/givps/givps/master/xray/cek-ws.sh" && chmod +x cek-ws

# vless
wget -O add-vless "https://raw.githubusercontent.com/givps/givps/master/xray/add-vless.sh" && chmod +x add-vless
wget -O trialvless "https://raw.githubusercontent.com/givps/givps/master/xray/trialvless.sh" && chmod +x trialvless
wget -O renew-vless "https://raw.githubusercontent.com/givps/givps/master/xray/renew-vless.sh" && chmod +x renew-vless
wget -O del-vless "https://raw.githubusercontent.com/givps/givps/master/xray/del-vless.sh" && chmod +x del-vless
wget -O cek-vless "https://raw.githubusercontent.com/givps/givps/master/xray/cek-vless.sh" && chmod +x cek-vless

# trojan
wget -O add-tr "https://raw.githubusercontent.com/givps/givps/master/xray/add-tr.sh" && chmod +x add-tr
wget -O trialtrojan "https://raw.githubusercontent.com/givps/givps/master/xray/trialtrojan.sh" && chmod +x trialtrojan
wget -O del-tr "https://raw.githubusercontent.com/givps/givps/master/xray/del-tr.sh" && chmod +x del-tr
wget -O renew-tr "https://raw.githubusercontent.com/givps/givps/master/xray/renew-tr.sh" && chmod +x renew-tr
wget -O cek-tr "https://raw.githubusercontent.com/givps/givps/master/xray/cek-tr.sh" && chmod +x cek-tr

# shadowsocks
wget -O add-ssws "https://raw.githubusercontent.com/givps/givps/master/xray/add-ssws.sh" && chmod +x add-ssws
wget -O trialssws "https://raw.githubusercontent.com/givps/givps/master/xray/trialssws.sh" && chmod +x trialssws
wget -O del-ssws "https://raw.githubusercontent.com/givps/givps/master/xray/del-ssws.sh" && chmod +x del-ssws
wget -O renew-ssws "https://raw.githubusercontent.com/givps/givps/master/xray/renew-ssws.sh" && chmod +x renew-ssws
wget -O cek-ssws "https://raw.githubusercontent.com/givps/givps/master/xray/cek-ssws.sh" && chmod +x cek-ssws

# xray cleaner
wget -O xray-cleaner "https://raw.githubusercontent.com/givps/givps/master/xray/xray-cleaner.sh" && chmod +x xray-cleaner

sleep 1
yellow "Xray/Vmess and Xray/Vless setup completed."

# Final cleanup
mv /root/domain /etc/xray/ 
rm -f /root/scdomain /root/ins-xray.sh

clear
echo -e "${green}==================================================${nc}"
echo -e " ✅ Instalasi Xray & Nginx Telah Selesai!"
echo -e " Domain yang digunakan: ${yellow}$DOMAIN${nc}"
echo -e " UUID (Password Default): ${yellow}$UUID${nc}"
echo -e " Semua layanan WS/gRPC mendengarkan di port ${yellow}443${nc} melalui Nginx."
echo -e "${green}==================================================${nc}"