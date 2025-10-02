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

# Detect authentication log file
if [ -e "/var/log/auth.log" ]; then
    LOG="/var/log/auth.log"
elif [ -e "/var/log/secure" ]; then
    LOG="/var/log/secure"
else
    echo "No authentication log file found!"
    exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DROPBEAR LOGINS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
pids=( $(ps aux | grep -i dropbear | awk '{print $2}') )
echo -e "${red}=========================================${nc}"
echo -e "${blue}           Active Dropbear Sessions       ${nc}"
echo -e "${red}=========================================${nc}"
echo "PID   |  Username   |  IP Address"
echo -e "${red}=========================================${nc}"

grep -i "dropbear" "$LOG" | grep -i "Password auth succeeded" > /tmp/login-db.txt
for PID in "${pids[@]}"; do
    grep "dropbear\[$PID\]" /tmp/login-db.txt > /tmp/login-db-pid.txt
    if [ -s /tmp/login-db-pid.txt ]; then
        USER=$(awk '{print $10}' /tmp/login-db-pid.txt | head -n1)
        IP=$(awk '{print $12}' /tmp/login-db-pid.txt | head -n1)
        echo "$PID   |  $USER   |  $IP"
    fi
done
echo -e "${red}=========================================${nc}"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OPENSSH LOGINS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${red}=========================================${nc}"
echo -e "${blue}            Active OpenSSH Sessions       ${nc}"
echo -e "${red}=========================================${nc}"
echo "PID   |  Username   |  IP Address"
echo -e "${red}=========================================${nc}"

grep -i "sshd" "$LOG" | grep -i "Accepted password for" > /tmp/login-ssh.txt
pids=( $(ps aux | grep "\[priv\]" | awk '{print $2}') )
for PID in "${pids[@]}"; do
    grep "sshd\[$PID\]" /tmp/login-ssh.txt > /tmp/login-ssh-pid.txt
    if [ -s /tmp/login-ssh-pid.txt ]; then
        USER=$(awk '{print $9}' /tmp/login-ssh-pid.txt | head -n1)
        IP=$(awk '{print $11}' /tmp/login-ssh-pid.txt | head -n1)
        echo "$PID   |  $USER   |  $IP"
    fi
done
echo -e "${red}=========================================${nc}"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OPENVPN TCP LOGINS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Active OpenVPN TCP Sessions     ${nc}"
    echo -e "${red}=========================================${nc}"
    echo "Username   |  IP Address   |  Connected Since"
    echo -e "${red}=========================================${nc}"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-tcp.log \
        | cut -d ',' -f 2,3,8 \
        | sed -e 's/,/      /g'
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OPENVPN UDP LOGINS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
    echo ""
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Active OpenVPN UDP Sessions     ${nc}"
    echo -e "${red}=========================================${nc}"
    echo "Username   |  IP Address   |  Connected Since"
    echo -e "${red}=========================================${nc}"
    grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-udp.log \
        | cut -d ',' -f 2,3,8 \
        | sed -e 's/,/      /g'
fi
echo -e "${red}=========================================${nc}"
echo ""

# Cleanup temporary files
rm -f /tmp/login-db.txt /tmp/login-db-pid.txt
rm -f /tmp/login-ssh.txt /tmp/login-ssh-pid.txt

read -n 1 -s -r -p "Press any key to return to the menu..."

m-sshovpn
