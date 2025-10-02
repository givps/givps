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

# VPS Information
domain=$(cat /etc/xray/domain 2>/dev/null)

# Certificate Status (days remaining)
cert_file="$HOME/.acme.sh/${domain}_ecc/${domain}.key"
if [[ -f "$cert_file" ]]; then
    modifyTime=$(stat -c %Y "$cert_file")
    currentTime=$(date +%s)
    stampDiff=$(( currentTime - modifyTime ))
    days=$(( stampDiff / 86400 ))
    remainingDays=$(( 90 - days ))
    [[ $remainingDays -le 0 ]] && tlsStatus="expired" || tlsStatus="$remainingDays days"
else
    tlsStatus="No certificate found"
fi

# OS Uptime
uptime="$(uptime -p | cut -d " " -f 2-10)"

# Network statistics (using interface eth0)
dtoday="$(vnstat -i eth0 | awk '/today/ {print $2,$3}')"
utoday="$(vnstat -i eth0 | awk '/today/ {print $5,$6}')"
ttoday="$(vnstat -i eth0 | awk '/today/ {print $8,$9}')"

# Yesterday
dyest="$(vnstat -i eth0 | awk '/yesterday/ {print $2,$3}')"
uyest="$(vnstat -i eth0 | awk '/yesterday/ {print $5,$6}')"
tyest="$(vnstat -i eth0 | awk '/yesterday/ {print $8,$9}')"

# Current Month
dmon="$(vnstat -i eth0 -m | grep "$(date +"%b '%y")" | awk '{print $3,$4}')"
umon="$(vnstat -i eth0 -m | grep "$(date +"%b '%y")" | awk '{print $6,$7}')"
tmon="$(vnstat -i eth0 -m | grep "$(date +"%b '%y")" | awk '{print $9,$10}')"

# User Info (placeholders)
Exp2="Lifetime"
Name="VIP-MEMBERS"

# CPU Information
cpu_usage1=$(ps aux | awk '{sum+=$3} END {print sum}')
cores=$(grep -c "^processor" /proc/cpuinfo)
cpu_usage=$(awk -v c="$cores" -v u="$cpu_usage1" 'BEGIN {printf "%.2f%%", (u/c)}')

DAY=$(date +%A)
DATE=$(date +%m/%d/%Y)
DATE2=$(date -R | cut -d " " -f -5)
IPVPS=$(curl -s ipv4.icanhazip.com)

cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo)
freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo)
tram=$(free -m | awk 'NR==2 {print $2}')
uram=$(free -m | awk 'NR==2 {print $3}')
fram=$(free -m | awk 'NR==2 {print $4}')

clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}                  VPS INFORMATION                 ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} OS            ${nc}: $(hostnamectl | grep 'Operating System' | cut -d ' ' -f5-)"
echo -e "${blue} Uptime        ${nc}: $uptime"
echo -e "${blue} Public IP     ${nc}: $IPVPS"
echo -e "${blue} Domain        ${nc}: $domain"
echo -e "${blue} TLS Cert      ${nc}: $tlsStatus"
echo -e "${blue} Date & Time   ${nc}: $DATE2"
echo -e "${red}=========================================${nc}"
echo -e "${blue}                    RAM INFO                      ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} RAM Used      ${nc}: $uram MB"
echo -e "${blue} RAM Total     ${nc}: $tram MB"
echo -e "${red}=========================================${nc}"
echo -e "${blue}                     MENU                         ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} 1${nc} : SSH Menu"
echo -e "${blue} 2${nc} : VMess Menu"
echo -e "${blue} 3${nc} : VLESS Menu"
echo -e "${blue} 4${nc} : Trojan Menu"
echo -e "${blue} 5${nc} : Shadowsocks Menu"
echo -e "${blue} 6${nc} : Settings Menu"
echo -e "${blue} 7${nc} : Service Status"
echo -e "${blue} 8${nc} : Clear RAM Cache"
echo -e "${blue} 9${nc} : Reboot VPS"
echo -e "${blue} x${nc} : Exit Script (run again with: menu)"
echo -e "${red}=========================================${nc}"
echo -e "${blue} Client Name   ${nc}: $Name"
echo -e "${blue} Expired       ${nc}: $Exp2"
echo -e "${red}=========================================${nc}"
echo -e "${blue}             t.me/givps_com  ${nc}"
echo ""
read -p " Select menu : " opt
echo ""

case $opt in
  1) clear ; m-sshovpn ;;
  2) clear ; m-vmess ;;
  3) clear ; m-vless ;;
  4) clear ; m-trojan ;;
  5) clear ; m-ssws ;;
  6) clear ; m-system ;;
  7) clear ; running ;;
  8) clear ; clearcache ;;
  9) clear ; reboot ;;
  x) exit ;;
  *) echo "Invalid selection." ; sleep 1 ; menu ;;
esac
