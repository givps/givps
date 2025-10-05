#!/bin/bash
# =========================================
# Name    : badvpn-installer
# Title   : Auto Script to Install and Configure badvpn-udpgw
# Version : 1.1 (Revised for Security and Robustness)
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

# Exit immediately if a command exits with a non-zero status.
# Exit if any command in a pipeline fails.
# Treat unset variables as an error.
set -euo pipefail

# --- Configuration ---
SOURCE_DIR="/root/badvpn"
BINARY_PATH="/usr/bin/badvpn-udpgw"
START_PORT=7100
END_PORT=7900
PORT_STEP=100

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

echo -e "${red}=========================================${nc}"
echo -e "${blue}  BadVPN UDPGW Compiler & Installer  ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "VPS IP: $MYIP"
echo -e "UDP Ports (Internal Loopback): ${START_PORT}, ${START_PORT+100}, ..., ${END_PORT}"
echo -e "${red}=========================================${nc}"

# --- Install dependencies ---
echo -e "${green}=== Updating & Installing dependencies (build-essential, cmake, git, screen) ===${nc}"
apt update -y > /dev/null
apt install -y build-essential cmake git screen

# --- Cloning & Building badvpn (udpgw only) ---
echo -e "${green}=== Cloning & Building badvpn-udpgw ===${nc}"
if [ ! -d "$SOURCE_DIR" ]; then
    git clone https://github.com/ambrop72/badvpn.git "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"
echo -e "${yellow}Compiling... (This may take a minute)${nc}"
cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make -j$(nproc)

# Check if the binary was created
if [ ! -f "udpgw/badvpn-udpgw" ]; then
    echo -e "${red}❌ ERROR: badvpn-udpgw binary not found after compilation.${nc}"
    exit 1
fi

echo -e "${green}=== Installing badvpn-udpgw binary ==="
cp udpgw/badvpn-udpgw "$BINARY_PATH"
chmod +x "$BINARY_PATH"
echo -e "${green}✅ badvpn-udpgw installed to $BINARY_PATH${nc}"

echo
echo -e "${blue}=== Select installation mode ===${nc}"
echo "1) Screen + rc.local (Legacy autostart, runs as root)"
echo "2) Systemd (Modern & stable, runs as nobody)"
read -rp "Choose [1/2]: " mode

if [ "$mode" == "1" ]; then
    # ----------------------------------------------------
    # MODE 1: Screen + rc.local
    # ----------------------------------------------------
    echo -e "${green}=== Installing screen + rc.local version ===${nc}"

    STARTUP_SCRIPT="/root/start-udpgw.sh"
    
    # Create start script
    cat > "$STARTUP_SCRIPT" <<EOF
#!/bin/bash
# Autostart BadVPN UDPGW services via screen
for port in \$(seq $START_PORT $PORT_STEP $END_PORT); do
    screen -dmS badvpn\$port $BINARY_PATH --listen-addr 127.0.0.1:\$port --max-clients 500
done
EOF
    chmod +x "$STARTUP_SCRIPT"

    # Create rc.local if not exists and ensure it's executable
    if [ ! -f /etc/rc.local ]; then
        echo -e "${yellow}Creating /etc/rc.local...${nc}"
        cat > /etc/rc.local <<EOT
#!/bin/bash
exit 0
EOT
        chmod +x /etc/rc.local
    fi

    # Add autostart only if the line doesn't exist
    if ! grep -q "$STARTUP_SCRIPT" /etc/rc.local; then
        sed -i "/^exit 0/i $STARTUP_SCRIPT" /etc/rc.local
        echo -e "${green}✅ Added $STARTUP_SCRIPT to /etc/rc.local${nc}"
    fi

    # Run immediately
    "$STARTUP_SCRIPT"
    echo -e "${green}=== BadVPN is running (Ports $START_PORT to $END_PORT) via screen + rc.local ===${nc}"
    echo -e "${yellow}Use 'screen -r badvpn7100' to attach.${nc}"

elif [ "$mode" == "2" ]; then
    # ----------------------------------------------------
    # MODE 2: Systemd
    # ----------------------------------------------------
    echo -e "${green}=== Installing systemd version ===${nc}"

    SERVICE_TEMPLATE="/etc/systemd/system/badvpn@.service"

    # Create systemd template unit
    cat > "$SERVICE_TEMPLATE" <<EOF
[Unit]
Description=BadVPN UDPGW Service (Port %i)
After=network.target

[Service]
# Security: Run as a low-privilege user
User=nobody
# Set necessary capabilities if needed, otherwise rely on system security
CapabilityBoundingSet=
AmbientCapabilities=
NoNewPrivileges=true

ExecStart=$BINARY_PATH --listen-addr 127.0.0.1:%i --max-clients 500
Restart=always
# Restart policy added for robustness
RestartSec=3s
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # Enable all ports from START_PORT to END_PORT (step PORT_STEP)
    for port in $(seq $START_PORT $PORT_STEP $END_PORT); do
        echo -e "${yellow}Enabling badvpn@${port}.service...${nc}"
        systemctl enable --now badvpn@${port}.service
    done

    echo -e "${green}=== BadVPN is running (Ports $START_PORT to $END_PORT) via systemd ===${nc}"
    echo -e "${yellow}Check status with: systemctl status badvpn@${START_PORT}${nc}"

else
    echo -e "${red}❌ Invalid choice! Aborting installation.${nc}"
    exit 1
fi

# --- Cleanup ---
echo -e "${green}=== Cleaning up build directory ===${nc}"
rm -rf "$SOURCE_DIR"
echo -e "${green}✅ Done! Build files removed.${nc}"

read -n 1 -s -r -p "Press any key to continue..."
# Assumed main menu function call
m-sshovpn 2>/dev/null || exit 0