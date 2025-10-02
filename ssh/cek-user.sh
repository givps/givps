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

# --- Menu ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}           SSH & VPN MENU          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e " [1] View Active SSH/Dropbear/OpenVPN Sessions"
echo -e " [2] Check Multi-Login Limit Violations"
echo -e " [x] Exit to Main Menu"
echo -e "${red}=========================================${nc}"
echo ""
read -p "Select an option [1-2 or x]: " opt

case $opt in
    1)
        clear
        echo "Checking VPS IP: $MYIP"
        echo ""

        # Detect system log file
        if [ -e "/var/log/auth.log" ]; then
            LOG="/var/log/auth.log"
        elif [ -e "/var/log/secure" ]; then
            LOG="/var/log/secure"
        else
            echo "No authentication log file found!"
            exit 1
        fi

        # -------- Dropbear --------
        data=( $(ps aux | grep -i dropbear | awk '{print $2}') )
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}        Dropbear Active Logins       ${nc}"
        echo -e "${red}=========================================${nc}"
        echo "PID   |  Username   |  IP Address"
        echo -e "${red}=========================================${nc}"
        grep -i dropbear "$LOG" | grep -i "Password auth succeeded" > /tmp/login-db.txt
        for PID in "${data[@]}"; do
            grep "dropbear\[$PID\]" /tmp/login-db.txt > /tmp/login-db-pid.txt
            NUM=$(wc -l < /tmp/login-db-pid.txt)
            USER=$(awk '{print $10}' /tmp/login-db-pid.txt)
            IP=$(awk '{print $12}' /tmp/login-db-pid.txt)
            if [ "$NUM" -eq 1 ]; then
                echo "$PID - $USER - $IP"
            fi
        done
        echo -e "${red}=========================================${nc}"
        echo ""

        # -------- OpenSSH --------
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}         OpenSSH Active Logins       ${nc}"
        echo -e "${red}=========================================${nc}"
        echo "PID   |  Username   |  IP Address"
        echo -e "${red}=========================================${nc}"
        grep -i sshd "$LOG" | grep -i "Accepted password for" > /tmp/login-ssh.txt
        data=( $(ps aux | grep "\[priv\]" | awk '{print $2}') )
        for PID in "${data[@]}"; do
            grep "sshd\[$PID\]" /tmp/login-ssh.txt > /tmp/login-ssh-pid.txt
            NUM=$(wc -l < /tmp/login-ssh-pid.txt)
            USER=$(awk '{print $9}' /tmp/login-ssh-pid.txt)
            IP=$(awk '{print $11}' /tmp/login-ssh-pid.txt)
            if [ "$NUM" -eq 1 ]; then
                echo "$PID - $USER - $IP"
            fi
        done
        echo -e "${red}=========================================${nc}"
        echo ""

        # -------- OpenVPN TCP --------
        if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
            echo -e "${red}=========================================${nc}"
            echo -e "${blue}       OpenVPN TCP Active Logins       ${nc}"
            echo -e "${red}=========================================${nc}"
            echo "Username   |  IP Address   |  Connected Since"
            echo -e "${red}=========================================${nc}"
            grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-tcp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g'
            echo -e "${red}=========================================${nc}"
            echo ""
        fi

        # -------- OpenVPN UDP --------
        if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
            echo -e "${red}=========================================${nc}"
            echo -e "${blue}       OpenVPN UDP Active Logins       ${nc}"
            echo -e "${red}=========================================${nc}"
            echo "Username   |  IP Address   |  Connected Since"
            echo -e "${red}=========================================${nc}"
            grep -w "^CLIENT_LIST" /etc/openvpn/server/openvpn-udp.log | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g'
            echo -e "${red}=========================================${nc}"
            echo ""
        fi

        # Cleanup
        rm -f /tmp/login-db.txt /tmp/login-db-pid.txt /tmp/login-ssh.txt /tmp/login-ssh-pid.txt
        read -n 1 -s -r -p "Press any key to return to the menu..."
        $0
    ;;
    2)
        clear
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}       MULTI-LOGIN VIOLATIONS       ${nc}"
        echo -e "${red}=========================================${nc}"
        if [ -e "/root/log-limit.txt" ]; then
            echo "Time - Username - Number of Sessions Killed"
            echo -e "${red}=========================================${nc}"
            cat /root/log-limit.txt
        else
            echo "No violations detected."
            echo "Or the AutoKill script has not been executed yet."
        fi
        echo -e "${red}=========================================${nc}"
        read -n 1 -s -r -p "Press any key to return to the menu..."
        $0
    ;;
    x)
        clear
        m-sshovpn
    ;;
    *)
        echo "Invalid option!"
        sleep 1
        $0
    ;;
esac
