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

# Detect VPS IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

# Colors for status
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[ON]${Font_color_suffix}"
Error="${Red_font_prefix}[OFF]${Font_color_suffix}"

# Check autokill status & details
if [[ -f /etc/cron.d/autokick ]]; then
    sts="${Info}"
    cron_line=$(grep -v '^#' /etc/cron.d/autokick | head -n 1)
    interval=$(echo "$cron_line" | awk '{print $1}' | grep -o '[0-9]*')
    max=$(echo "$cron_line" | awk '{print $NF}')
    [[ -z "$interval" ]] && interval="Unknown"
    [[ -z "$max" ]] && max="Unknown"
else
    sts="${Error}"
    interval="Disabled"
    max="N/A"
fi

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}             AUTOKILL SSH          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e " VPS IP          : $MYIP"
echo -e " Autokill Status : $sts"
echo -e " Interval        : $interval minute(s)"
echo -e " Max MultiLogin  : $max"
echo -e "${red}=========================================${nc}"
echo -e ""
echo -e "[1]  AutoKill Every 5 Minutes"
echo -e "[2]  AutoKill Every 10 Minutes"
echo -e "[3]  AutoKill Every 15 Minutes"
echo -e "[4]  Disable AutoKill / MultiLogin"
echo -e "[5]  Custom Interval (Minutes)"
echo -e "[6]  Show Current Status Only"
echo ""
echo -e "${red}=========================================${nc}"
echo -e ""

read -rp "Select an option [1-6 or Ctrl+C to exit]: " AutoKill
if [[ -z "$AutoKill" ]]; then
    echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Input cannot be empty!"
    exit 1
fi

# For options 1–3 and 5, ask for max multi-login allowed
if [[ "$AutoKill" =~ ^[1-3]$|^5$ ]]; then
    read -rp "Enter maximum number of allowed multi-login sessions: " max
    if [[ -z "$max" || ! "$max" =~ ^[0-9]+$ ]]; then
        echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Value must be a number!"
        exit 1
    fi
fi

case $AutoKill in
    1)
        echo "# Autokill" > /etc/cron.d/autokick
        echo "*/5 * * * * root /usr/bin/autokick $max" >> /etc/cron.d/autokick
        echo -e "✅ Autokill set every 5 minutes | Max Login: $max"
        ;;
    2)
        echo "# Autokill" > /etc/cron.d/autokick
        echo "*/10 * * * * root /usr/bin/autokick $max" >> /etc/cron.d/autokick
        echo -e "✅ Autokill set every 10 minutes | Max Login: $max"
        ;;
    3)
        echo "# Autokill" > /etc/cron.d/autokick
        echo "*/15 * * * * root /usr/bin/autokick $max" >> /etc/cron.d/autokick
        echo -e "✅ Autokill set every 15 minutes | Max Login: $max"
        ;;
    4)
        rm -f /etc/cron.d/autokick
        echo -e "❌ Autokill MultiLogin disabled"
        ;;
    5)
        read -rp "Enter custom interval (minutes): " interval
        if [[ -z "$interval" || ! "$interval" =~ ^[0-9]+$ ]]; then
            echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Interval must be a number!"
            exit 1
        fi
        echo "# Autokill" > /etc/cron.d/autokick
        echo "*/$interval * * * * root /usr/bin/autokick $max" >> /etc/cron.d/autokick
        echo -e "✅ Autokill set every $interval minutes | Max Login: $max"
        ;;
    6)
        echo ""
        echo -e "${red}=========================================${nc}"
        echo " 🔎 Current Autokill Status:"
        echo " Status     : $sts"
        echo " Interval   : $interval minute(s)"
        echo " Max Login  : $max"
        echo -e "${red}=========================================${nc}"
        exit 0
        ;;
    *)
        echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Invalid option!"
        exit 1
        ;;
esac

# Restart cron service
systemctl restart cron >/dev/null 2>&1
echo -e "${Green_font_prefix}[OK]${Font_color_suffix} Autokill setting applied successfully!"
