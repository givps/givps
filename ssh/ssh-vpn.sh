#!/bin/bash
# =========================================
# Name    : initial-vps-setup
# Title   : Auto Script VPS - VPN Manager for Debian & Ubuntu
# Version : 1.1 (Security and Reliability Hardening)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

# Get IP VPS
MYIP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || ip a | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -vE '^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.|^10\.|^127\.|^255\.|^0\.' | head -n 1)

# Check if IP was found
if [[ -z "$MYIP" ]]; then
    echo -e "${red}FATAL: Could not determine public IP address. Exiting.${nc}"
    exit 1
fi
MYIP2="s/xxxxxxxxx/$MYIP/g"

# detail organizations for SSL cert
COUNTRY="ID"
STATE="Indonesia"
LOCALITY="Jakarta"
ORGANIZATION="VPN-Service"
ORG_UNIT="IT-Support"
COMMON_NAME="$MYIP"
EMAIL="admin@$MYIP.com"

# --- System Preparation ---
echo -e "${green}=== 1. System Update and Essential Tools ===${nc}"
apt update -y
apt dist-upgrade -y
# Use --auto-remove instead of --purge -y ufw... for cleaner removal
apt-get remove --auto-remove -y ufw firewalld exim4 2>/dev/null || true

# Install tools
apt install -y \
    screen curl jq bzip2 gzip vnstat coreutils rsyslog iftop zip unzip git \
    apt-transport-https build-essential figlet ruby python3 make cmake \
    net-tools nano sed gnupg gnupg1 bc dirmngr libxml-parser-perl neofetch \
    lsof libsqlite3-dev libz-dev gcc g++ libreadline-dev zlib1g-dev \
    libssl-dev libssl1.0-dev dos2unix fail2ban dropbear stunnel4 \
    wget curl shc netfilter-persistent iptables-persistent

# --- WARNING: REMOVING RISKY PASSWORD POLICY CHANGE ---
# The original script downloaded and replaced /etc/pam.d/common-password via a
# hardcoded key. This is a severe security risk. It has been removed.
# To enforce modern password policy, we install pwquality.
echo -e "${yellow}Removed risky password policy download.${nc}"
apt install -y libpam-pwquality 2>/dev/null || true

# --- Timezone and Locale ---
echo -e "${green}=== 2. Timezone and SSH Locale ===${nc}"
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
# Disable locale environment passing to prevent SSH login delays
sed -i 's/^AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# --- rc.local Service Setup (Standard Systemd Method) ---
echo -e "${green}=== 3. rc.local and IPv6 Disable ===${nc}"
cat > /etc/systemd/system/rc-local.service <<-EOF
[Unit]
Description=/etc/rc.local compatibility
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/rc.local <<-EOF
#!/bin/sh -e
# Disable IPv6 permanently
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
exit 0
EOF
chmod +x /etc/rc.local
systemctl daemon-reload
systemctl enable rc-local
systemctl start rc-local.service 2>/dev/null || true

# Immediate disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

# --- Nginx and Web Server ---
echo -e "${green}=== 4. Nginx and Web Root Setup ===${nc}"
apt install -y nginx
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default 2>/dev/null
# Fetch Nginx configuration files
wget -q -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/givps/givps/master/ssh/nginx.conf"
wget -q -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/givps/givps/master/ssh/vps.conf"
systemctl daemon-reload
systemctl restart nginx

mkdir -p /home/vps/public_html
wget -q -O /home/vps/public_html/index.html "https://raw.githubusercontent.com/givps/givps/master/ssh/index"
wget -q -O /home/vps/public_html/.htaccess "https://raw.githubusercontent.com/givps/givps/master/ssh/.htaccess"
chown -R www-data:www-data /home/vps/public_html

# --- badvpn-udpgw ---
echo -e "${green}=== 5. Badvpn-udpgw Installation ===${nc}"
wget -q -O install-udpgw-unified "https://raw.githubusercontent.com/givps/givps/master/ssh/install-udpgw-unified.sh"
chmod +x install-udpgw-unified
./install-udpgw-unified

# --- OpenSSH Configuration ---
echo -e "${green}=== 6. OpenSSH Hardening ===${nc}"
# Add extra ports for OpenSSH
for port in 500 40000 81 110 51443 58080 666 200 2222 2269; do
    if ! grep -q "^Port $port" /etc/ssh/sshd_config; then
        echo "Port $port" >> /etc/ssh/sshd_config
    fi
done
systemctl restart ssh

# --- Dropbear Configuration ---
echo -e "${green}=== 7. Dropbear Configuration ===${nc}"
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
# Remove conflicting default 22 port, set main ports
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=143/' /etc/default/dropbear
# Add extra ports (50000, 109, 110, 69)
sed -i 's@DROPBEAR_EXTRA_ARGS=@DROPBEAR_EXTRA_ARGS="-p 50000 -p 109 -p 110 -p 69"@' /etc/default/dropbear
# Add /bin/false and /usr/sbin/nologin to shells for user creation safety
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
systemctl restart dropbear

# --- Stunnel4 Configuration ---
echo -e "${green}=== 8. Stunnel4 (SSL/TLS Tunnel) ===${nc}"
# Use defined variables for certificate generation
OPENSSL_SUBJECT="/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

cat > /etc/stunnel/stunnel.conf <<-EOF
cert = /etc/stunnel/stunnel.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear-ssh] 
accept = 222
connect = 127.0.0.1:22
[dropbear-alt]
accept = 777
connect = 127.0.0.1:109
[ws-stunnel]
accept = 2096
connect = 700
[openvpn]
accept = 442
connect = 127.0.0.1:1194
EOF

# Generate SSL certificate
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 1095 -subj "$OPENSSL_SUBJECT"
cat key.pem cert.pem >> /etc/stunnel/stunnel.pem
rm -f key.pem cert.pem
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable stunnel4
systemctl restart stunnel4

# --- Banner Setup ---
echo -e "${green}=== 9. Login Banner ===${nc}"
wget -q -O /etc/issue.net "https://raw.githubusercontent.com/givps/givps/master/banner/banner.conf"
echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@' /etc/default/dropbear

# --- DDoS Deflate ---
echo -e "${green}=== 10. Install DDoS Deflate ===${nc}"
if [ ! -d "/usr/local/ddos" ]; then
    mkdir /usr/local/ddos
    wget -q -O /usr/local/ddos/ddos.sh http://www.inetbase.com/scripts/ddos/ddos.sh
    chmod 0755 /usr/local/ddos/ddos.sh
    ln -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos
    # Run setup to add cron job
    /usr/local/ddos/ddos.sh --cron >/dev/null 2>&1
fi

# --- Blocking Torrent Traffic (FORWARD Chain for VPN clients) ---
echo -e "${green}=== 11. Blocking Torrent Keywords ===${nc}"
# Clear existing rules related to this before adding new ones
iptables -D FORWARD -m string --algo bm --string "get_peers" -j DROP 2>/dev/null || true

for key in "get_peers" "announce_peer" "find_node" "BitTorrent" \
"BitTorrent protocol" "peer_id=" ".torrent" "announce.php?passkey=" \
"torrent" "announce" "info_hash"; do
    iptables -A FORWARD -m string --algo bm --string "$key" -j DROP
done
netfilter-persistent save
netfilter-persistent reload

# --- 12. Download Menu Files and Scripts ---
echo -e "${green}=== Downloading Menu and Utility Scripts ===${nc}"
cd /usr/bin
REPO_URL="https://raw.githubusercontent.com/givps/givps/master"

# Array of scripts to download (using the latest stable names for clarity)
declare -A scripts=(
    [menu]="menu/menu.sh" 
    [m-vmess]="menu/m-vmess.sh"
    [m-vless]="menu/m-vless.sh"
    [running]="menu/running.sh"
    [clearcache]="menu/clearcache.sh"
    [m-ssws]="menu/m-ssws.sh"
    [m-trojan]="menu/m-trojan.sh"
    [m-sshovpn]="menu/m-sshovpn.sh"
    [usernew]="ssh/usernew.sh"
    [trial]="ssh/trial.sh"
    [renew]="ssh/renew.sh"
    [delete]="ssh/delete.sh"
    [cek]="ssh/cek.sh"
    [member]="ssh/member.sh"
    [auto-delete]="ssh/auto-delete.sh"
    [auto-kill]="ssh/auto-kill.sh"
    [cek-user]="ssh/cek-user.sh"
    [auto-kick]="ssh/auto-kick.sh"
    [sshws]="ssh/sshws.sh"
    [user-lockunlock]="ssh/user-lockunlock.sh"
    [m-system]="menu/m-system.sh"
    [m-domain]="menu/m-domain.sh"
    [add-host]="ssh/add-host.sh"
    [xray-crt]="xray/xray-crt.sh"
    [auto-reboot]="menu/auto-reboot.sh"
    [restart]="menu/restart.sh"
    [cek-bw]="menu/cek-bw.sh"
    [m-tcp]="menu/tcp.sh"
    [xp]="ssh/xp.sh"
    [m-dns]="menu/m-dns.sh"
)

for cmd in "${!scripts[@]}"; do
    wget -q -O "$cmd" "$REPO_URL/${scripts[$cmd]}"
done

# Set execution permissions
chmod +x /usr/bin/*

# --- 13. Cron Jobs ---
echo -e "${green}=== Setting up Cron Jobs ===${nc}"
# Standard auto reboot at 2 AM
cat > /etc/cron.d/re_otm <<-EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 2 * * * root /sbin/reboot
EOF

# Expired user check at midnight
cat > /etc/cron.d/xp_otm <<-EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/xp
EOF

# --- 14. Final Cleanup and Finish ---
echo -e "${green}=== Final Cleanup ===${nc}"
# Install speedtest (using modern method)
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
apt-get install -y speedtest || true

# Clear trash
apt autoremove -y
apt autoclean -y
history -c
echo "unset HISTFILE" >> /etc/profile

# Restart remaining services
systemctl restart nginx cron ssh dropbear fail2ban stunnel4 vnstat 2>/dev/null || true

clear
echo -e "${green}=========================================${nc}"
echo -e "${blue}✅ Initial VPS Setup Completed Successfully! ✅${nc}"
echo -e "${red}=========================================${nc}"
echo -e "IP Address : $MYIP"
echo -e "OpenSSH    : 22, ${PORT_OPENSSH}"
echo -e "Dropbear   : 143, 109, 110, 69, 50000"
echo -e "Stunnel4   : 222 (to SSH), 777 (to Dropbear 109), 2096 (to 700)"
echo -e "Web Panel  : http://$MYIP:81"
echo -e "UDPGW      : 7100-7900"
echo -e "${red}=========================================${nc}"
echo -e "Type ${yellow}menu${nc} to display the user management console."
echo -e "${red}=========================================${nc}"