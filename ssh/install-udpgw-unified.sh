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
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

# Unified Installer for badvpn-udpgw
# Options: screen (rc.local) or systemd
# Tested on Ubuntu/Debian

echo -e "${green}=== Updating & Installing dependencies ===${nc}"
apt update -y && apt install -y build-essential cmake git screen

echo "=== Cloning & Building badvpn (udpgw only) ==="
cd /root
if [ ! -d "badvpn" ]; then
    git clone https://github.com/ambrop72/badvpn.git
fi
cd badvpn
cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make

echo "=== Installing badvpn-udpgw binary ==="
cp udpgw/badvpn-udpgw /usr/bin/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw

echo
echo -e "${blue}=== Select installation mode ===${nc}"
echo "1) Screen + rc.local (old style, similar to legacy scripts)"
echo "2) Systemd (modern & stable)"
read -p "Choose [1/2]: " mode

if [ "$mode" == "1" ]; then
    echo -e "${green}=== Installing screen + rc.local version ===${nc}"

    # Create start script
    cat > /root/start-udpgw.sh <<'EOF'
#!/bin/bash
for port in {7100..7900..100}; do
    screen -dmS badvpn$port /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:$port --max-clients 500
done
EOF
    chmod +x /root/start-udpgw.sh

    # Create rc.local if not exists
    if [ ! -f /etc/rc.local ]; then
        cat > /etc/rc.local <<EOF
#!/bin/bash
exit 0
EOF
        chmod +x /etc/rc.local
    fi

    # Add autostart before exit 0
    sed -i '/^exit 0/i /root/start-udpgw.sh' /etc/rc.local

    # Run immediately
    /root/start-udpgw.sh
    echo "=== badvpn-udpgw is running (7100, 7200, ..., 7900) via screen + rc.local ==="

elif [ "$mode" == "2" ]; then
    echo -e "${green}=== Installing systemd version ===${nc}"

    # Create systemd template unit
    cat > /etc/systemd/system/badvpn@.service <<EOF
[Unit]
Description=BadVPN UDPGW Service on port %i
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:%i --max-clients 500
Restart=always
User=nobody
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # Enable all ports from 7100 to 7900 (step 100)
    for port in $(seq 7100 100 7900); do
        systemctl enable --now badvpn@${port}.service
    done

    echo "=== badvpn-udpgw is running (7100, 7200, ..., 7900) via systemd ==="
    echo "Check with: systemctl status badvpn@7100"

else
    echo "Invalid choice!"
    exit 1
fi
