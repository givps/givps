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

# --- Detect XRAY / V2RAY domain ---
if grep -q "XRAY" ~/log-install.txt; then
    DOMAIN=$(cat /etc/xray/domain)
else
    DOMAIN=$(cat /etc/v2ray/domain)
fi

# --- Extract service ports from log ---
PORT_SSH_WS=$(grep -w "noneTLS" ~/log-install.txt | cut -d: -f2 | awk '{print $1}')
PORT_SSH_SSL_WS=$(grep -w "TLS" ~/log-install.txt | cut -d: -f2 | awk '{print $1}')
PORT_OPENSSH=$(grep -w "OpenSSH" ~/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')
PORT_DROPBEAR=$(grep -w "Dropbear" ~/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')
PORT_SSL=$(grep -w "Stunnel4" ~/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')

# --- Trial Account Settings ---
USER="trial$(tr -dc X-Z0-9 </dev/urandom | head -c4)"
PASS="1"
DAYS_ACTIVE=1

# --- Create Trial Account ---
useradd -e "$(date -d "$DAYS_ACTIVE days" +"%Y-%m-%d")" -s /bin/false -M "$USER"
echo -e "$PASS\n$PASS\n" | passwd "$USER" &>/dev/null
EXP_DATE=$(chage -l "$USER" | grep "Account expires" | awk -F": " '{print $2}')

# --- Ask max login limit ---
read -p "Enter max simultaneous logins (default=1): " MAX_LOGIN
MAX_LOGIN=${MAX_LOGIN:-1}

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}            TRIAL SSH              ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "Username   : $USER"
echo -e "Password   : $PASS"
echo -e "Expired On : $EXP_DATE"
echo -e "Max Login  : $MAX_LOGIN"
echo -e "${red}=========================================${nc}"
echo -e "IP         : $MYIP"
echo -e "Host       : $DOMAIN"
echo -e "OpenSSH    : $PORT_OPENSSH"
echo -e "Dropbear   : $PORT_DROPBEAR"
echo -e "SSH WS     : $PORT_SSH_WS"
echo -e "SSH SSL WS : $PORT_SSH_SSL_WS"
echo -e "Stunnel4   : $PORT_SSL"
echo -e "UDPGW      : 7100-7900"
echo -e "${red}=========================================${nc}"
echo -e "Payload WSS"
echo -e "GET wss://bug.com HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "${red}=========================================${nc}"
echo -e "Payload WS"
echo -e "GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "${red}=========================================${nc}"

# --- Auto Remove Expired Accounts ---
TODAY=$(date +%s)
while IFS=: read -r u _; do
    if [ -n "$u" ]; then
        EXP=$(chage -l "$u" 2>/dev/null | grep "Account expires" | awk -F": " '{print $2}')
        if [[ "$EXP" != "never" && -n "$EXP" ]]; then
            EXP_SECS=$(date -d "$EXP" +%s 2>/dev/null)
            if [ "$EXP_SECS" -lt "$TODAY" ]; then
                userdel -r "$u"
                echo "$(date +"%Y-%m-%d %X") - Removed expired user: $u" >> /root/expired-users.log
            fi
        fi
    fi
done < /etc/passwd

# --- Limit Login Check ---
LOG_FILE=""
if [ -e "/var/log/auth.log" ]; then
    OS=1
    LOG_FILE="/var/log/auth.log"
elif [ -e "/var/log/secure" ]; then
    OS=2
    LOG_FILE="/var/log/secure"
fi

if [ -n "$LOG_FILE" ]; then
    USERS=$(grep "/home/" /etc/passwd | cut -d: -f1)

    for U in $USERS; do
        COUNT=0
        PIDS=""

        # Dropbear check
        DBLOG=$(grep -i dropbear "$LOG_FILE" | grep -i "Password auth succeeded")
        for PID in $(ps aux | grep -i dropbear | awk '{print $2}'); do
            if grep -q "dropbear\[$PID\]" <<< "$DBLOG"; then
                LOGIN_USER=$(grep "dropbear\[$PID\]" <<< "$DBLOG" | awk '{print $10}')
                if [ "$LOGIN_USER" == "$U" ]; then
                    COUNT=$((COUNT + 1))
                    PIDS="$PIDS $PID"
                fi
            fi
        done

        # SSH check
        SSHLOG=$(grep -i sshd "$LOG_FILE" | grep -i "Accepted password for")
        for PID in $(ps aux | grep "\[priv\]" | awk '{print $2}'); do
            if grep -q "sshd\[$PID\]" <<< "$SSHLOG"; then
                LOGIN_USER=$(grep "sshd\[$PID\]" <<< "$SSHLOG" | awk '{print $9}')
                if [ "$LOGIN_USER" == "$U" ]; then
                    COUNT=$((COUNT + 1))
                    PIDS="$PIDS $PID"
                fi
            fi
        done

        # Kill if exceeding limit
        if [ $COUNT -gt $MAX_LOGIN ]; then
            DATE_NOW=$(date +"%Y-%m-%d %X")
            echo "$DATE_NOW - $U - $COUNT" >> /root/log-limit.txt
            kill $PIDS
            echo "User $U exceeded limit ($COUNT logins > $MAX_LOGIN) and was kicked."
        fi
    done

    # Restart services
    if [ "$OS" -eq 1 ]; then
        service ssh restart >/dev/null 2>&1
    elif [ "$OS" -eq 2 ]; then
        service sshd restart >/dev/null 2>&1
    fi
    service dropbear restart >/dev/null 2>&1
fi

echo ""
read -n 1 -s -r -p "Press any key to return to menu"
m-sshovpn
