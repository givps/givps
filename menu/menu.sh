#!/bin/bash
# =========================================
# Name    : main-menu-dashboard
# Title   : Auto Script VPS Main Menu and System Information Dashboard
# Version : 1.1 (Robustness and Accuracy)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Variables and Paths ---
DOMAIN_FILE="/etc/xray/domain"
CERT_DIR="$HOME/.acme.sh"
LOG_DIR="/var/log" # Placeholder for service status checks

# --- Functions for System Info ---

# Function to determine the main network interface for vnstat
get_main_interface() {
    # Check vnstat's primary interface or fall back to 'eth0' or 'ensX'
    if command -v vnstat >/dev/null; then
        vnstat --iflist 2>/dev/null | awk 'NR==2{print $1}' || \
        ip route | awk '/default/ {print $5; exit}' || \
        echo "eth0"
    else
        echo "eth0"
    fi
}

# Function to check Certificate Status
check_tls_status() {
    local domain
    domain=$(cat "$DOMAIN_FILE" 2>/dev/null || echo "")

    if [[ -z "$domain" ]]; then
        echo "${yellow}Domain file not found${nc}"
        return
    fi

    local cert_file="$CERT_DIR/${domain}_ecc/${domain}.key"

    if [[ -f "$cert_file" ]]; then
        local expiry_date
        # Use openssl for a more accurate expiry check if available, otherwise rely on file timestamp
        if command -v openssl >/dev/null; then
            expiry_date=$(openssl x509 -in "$CERT_DIR/${domain}_ecc/fullchain.cer" -noout -enddate 2>/dev/null | cut -d '=' -f 2)
            if [[ -n "$expiry_date" ]]; then
                local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo 0)
                local current_epoch=$(date +%s)
                local remaining_seconds=$(( expiry_epoch - current_epoch ))
                local remaining_days=$(( remaining_seconds / 86400 ))
                
                if [[ "$remaining_days" -lt 0 ]]; then
                    echo "${red}EXPIRED${nc}"
                elif [[ "$remaining_days" -lt 14 ]]; then
                    echo "${yellow}WARNING: $remaining_days days${nc}"
                else
                    echo "${green}$remaining_days days${nc}"
                fi
                return
            fi
        fi

        # Fallback to file modification time if openssl fails or is not present
        local modifyTime=$(stat -c %Y "$cert_file")
        local currentTime=$(date +%s)
        local stampDiff=$(( currentTime - modifyTime ))
        local days=$(( stampDiff / 86400 ))
        local remainingDays=$(( 90 - days ))

        if [[ "$remainingDays" -le 0 ]]; then
            echo "${red}EXPIRED (File Check)${nc}"
        elif [[ "$remainingDays" -lt 14 ]]; then
            echo "${yellow}WARNING: $remainingDays days (File Check)${nc}"
        else
            echo "${green}$remainingDays days (File Check)${nc}"
        fi
    else
        echo "${red}No certificate found${nc}"
    fi
}

# --- Main Menu Loop ---
while true; do
    
    # --- Data Collection ---
    clear

    # Get VPS Information
    IPVPS=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "N/A")
    domain=$(cat "$DOMAIN_FILE" 2>/dev/null || echo "${red}N/A${nc}")
    
    # Certificate Status
    tlsStatus=$(check_tls_status)

    # OS Uptime
    uptime_info=$(uptime -p 2>/dev/null | cut -d " " -f 2-10 || echo "N/A")

    # Network statistics (Requires vnstat and determined interface)
    INTERFACE=$(get_main_interface)
    
    # Use vnstat if available
    if command -v vnstat >/dev/null; then
        dtoday="$(vnstat -i "$INTERFACE" 2>/dev/null | awk '/today/ {print $2,$3}' || echo "N/A")"
        utoday="$(vnstat -i "$INTERFACE" 2>/dev/null | awk '/today/ {print $5,$6}' || echo "N/A")"
        ttoday="$(vnstat -i "$INTERFACE" 2>/dev/null | awk '/today/ {print $8,$9}' || echo "N/A")"
        
        dmon="$(vnstat -i "$INTERFACE" -m 2>/dev/null | grep "$(date +"%b '%y")" | awk '{print $3,$4}' || echo "N/A")"
        umon="$(vnstat -i "$INTERFACE" -m 2>/dev/null | grep "$(date +"%b '%y")" | awk '{print $6,$7}' || echo "N/A")"
        tmon="$(vnstat -i "$INTERFACE" -m 2>/dev/null | grep "$(date +"%b '%y")" | awk '{print $9,$10}' || echo "N/A")"
    else
        dtoday="N/A" ; utoday="N/A" ; ttoday="N/A"
        dmon="N/A" ; umon="N/A" ; tmon="N/A"
    fi

    # RAM Info
    tram=$(free -m | awk 'NR==2 {print $2}' 2>/dev/null || echo "N/A")
    uram=$(free -m | awk 'NR==2 {print $3}' 2>/dev/null || echo "N/A")

    # CPU Info (Simplified to avoid unreliable ps aux summation)
    cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[[:space:]]*//' || echo "N/A")
    cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "N/A")
    
    # User Info (placeholders from original script)
    Exp2="Lifetime"
    Name="VIP-MEMBERS"

    # Date & Time
    DATE2=$(date -R | cut -d " " -f -5)

    # --- Display Dashboard ---
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}              VPS INFORMATION             ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} OS            ${nc}: $(hostnamectl | grep 'Operating System' | cut -d ' ' -f5-)"
    echo -e "${blue} Uptime        ${nc}: $uptime_info"
    echo -e "${blue} Public IP     ${nc}: $IPVPS"
    echo -e "${blue} Domain        ${nc}: $domain"
    echo -e "${blue} TLS Cert      ${nc}: $tlsStatus"
    echo -e "${blue} Date & Time   ${nc}: $DATE2"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}                 CPU & RAM INFO             ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} CPU Model     ${nc}: $cname"
    echo -e "${blue} CPU Cores     ${nc}: $cores"
    echo -e "${blue} RAM Used      ${nc}: $uram MB"
    echo -e "${blue} RAM Total     ${nc}: $tram MB"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}                 NETWORK USAGE             ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} Interface     ${nc}: $INTERFACE"
    echo -e "${blue} Today (D/U/T) ${nc}: $dtoday / $utoday / $ttoday"
    echo -e "${blue} Month (D/U/T) ${nc}: $dmon / $umon / $tmon"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}                    MENU                  ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} 1${nc} : SSH Menu (m-sshovpn)"
    echo -e "${blue} 2${nc} : VMess Menu (m-vmess)"
    echo -e "${blue} 3${nc} : VLESS Menu (m-vless)"
    echo -e "${blue} 4${nc} : Trojan Menu (m-trojan)"
    echo -e "${blue} 5${nc} : Shadowsocks Menu (m-ssws)"
    echo -e "${blue} 6${nc} : Settings Menu (m-system)"
    echo -e "${blue} 7${nc} : Service Status (running)"
    echo -e "${blue} 8${nc} : Clear RAM Cache (clearcache)"
    echo -e "${blue} 9${nc} : Reboot VPS"
    echo -e "${blue} x${nc} : Exit Script"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} Client Name   ${nc}: $Name"
    echo -e "${blue} Expired       ${nc}: $Exp2"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             t.me/givps_com             ${nc}"
    echo ""

    read -rp " Select menu : " opt
    echo ""

    case "$opt" in
      1) clear ; m-sshovpn ;;
      2) clear ; m-vmess ;;
      3) clear ; m-vless ;;
      4) clear ; m-trojan ;;
      5) clear ; m-ssws ;;
      6) clear ; m-system ;;
      7) clear ; running ;;
      8) clear ; clearcache ;;
      9) clear ; reboot ;;
      x) exit 0 ;;
      *) echo -e "${red}Invalid selection!${nc}" ; sleep 1 ;;
    esac
done