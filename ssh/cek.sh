#!/bin/bash
# =========================================
# Name    : active-session-checker
# Title   : Auto Script VPS to Display Active VPN and SSH Sessions
# Version : 1.1 (Revised for Reliability using 'w' and 'ps')
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
blue='\e[1;34m'
nc='\e[0m'

# Detect VPS Public IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

# --- Session Display Function ---
display_sessions() {
    clear
    echo "Checking VPS IP: $MYIP"
    echo ""

    # ----------------------------------------------------
    # 1. SSH (OpenSSH and Dropbear using reliable process check)
    # ----------------------------------------------------
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        Active SSH & Dropbear Sessions    ${nc}"
    echo -e "${red}=========================================${nc}"
    echo "PID   | User           | Source IP   | Login Type"
    echo -e "${red}-----------------------------------------${nc}"

    # Use 'ps' to find active SSH (sshd: user@) and Dropbear processes
    # Filter only processes that represent an authenticated session (not the master or unprivileged process)
    ps aux | grep -E 'sshd: .+@|dropbear' | grep -vE 'grep|/usr/sbin/sshd -D|dropbear -[RE]' | while read -r line; do
        PID=$(echo "$line" | awk '{print $2}')
        USER=$(echo "$line" | awk '{print $1}')
        CMD=$(echo "$line" | awk '{for (i=11; i<=NF; i++) printf "%s ", $i}')
        
        LOGIN_TYPE=""
        
        # Check for standard OpenSSH session command line
        if [[ "$CMD" =~ ^sshd:.+@ ]]; then
            # Extract IP from the sshd process title
            IP=$(echo "$CMD" | grep -oP 'from\s+\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            LOGIN_TYPE="OpenSSH"
        # Check for Dropbear session command line
        elif [[ "$CMD" =~ dropbear ]]; then
            # Find the peer IP by checking network connections (ss)
            IP=$(ss -tnp | grep "$PID" | awk '{print $NF}' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            LOGIN_TYPE="Dropbear"
        else
            continue # Skip non-session processes
        fi

        # Filter out system users (UID < 1000) for clean display
        if [[ $(id -u "$USER" 2>/dev/null) -ge 1000 ]]; then
            printf "%-5s | %-14s | %-11s | %s\n" "$PID" "$USER" "${IP:-N/A}" "$LOGIN_TYPE"
        fi
    done
    
    echo -e "${red}=========================================${nc}"
    echo ""

    # ----------------------------------------------------
    # 2. OpenVPN Sessions (TCP and UDP)
    # ----------------------------------------------------
    
    # Function to parse and display OpenVPN status log
    parse_openvpn_log() {
        local log_file=$1
        local protocol=$2

        if [ -f "$log_file" ] && grep -q "^CLIENT_LIST" "$log_file"; then
            echo -e "${red}=========================================${nc}"
            echo -e "${blue}          Active OpenVPN $protocol Sessions     ${nc}"
            echo -e "${red}=========================================${nc}"
            echo "Username   |  IP Address   |  Connected Since"
            echo -e "${red}-----------------------------------------${nc}"
            
            # Use grep and cut to extract relevant fields: Client Name (2), Real Address (3), Connected Since (8)
            grep -w "^CLIENT_LIST" "$log_file" \
                | cut -d ',' -f 2,3,8 \
                | sed -e 's/,/      /g'
            
            echo -e "${red}=========================================${nc}"
            echo ""
        fi
    }

    # Check and display OpenVPN TCP sessions
    parse_openvpn_log "/etc/openvpn/server/openvpn-tcp.log" "TCP"

    # Check and display OpenVPN UDP sessions
    parse_openvpn_log "/etc/openvpn/server/openvpn-udp.log" "UDP"

}

# --- Main Execution ---
display_sessions

read -n 1 -s -r -p "Press any key to return to the menu..."

# Execute the presumed main menu function
m-sshovpn 2>/dev/null || exit 0