#!/bin/bash
# =========================================
# Name    : session-checker-menu
# Title   : Interactive Menu for SSH/VPN Session Status
# Version : 1.1 (Revised for Reliability using 'w' and 'ss')
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
blue='\e[1;34m'
nc='\e[0m'

# --- Configuration ---
MYIP=$(wget -qO- ipv4.icanhazip.com)
LOG_LIMIT_FILE="/root/log-limit.txt"
OVPN_STATUS_TCP="/etc/openvpn/server/openvpn-tcp.log" # Assume this is the 'status.log' file
OVPN_STATUS_UDP="/etc/openvpn/server/openvpn-udp.log"

# Function to safely return to this script's menu
return_to_menu() {
    read -n 1 -s -r -p "Press any key to return to the menu..."
    # Execute the current script again to show the menu
    $0
}

# Function to reliably display SSH/Dropbear sessions
check_ssh_dropbear_sessions() {
    clear
    echo "Checking VPS IP: $MYIP"
    echo ""
    
    # --- OpenSSH & Standard SSH (Reliable Method) ---
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}        SSH Active Sessions (w/ who) ${nc}"
    echo -e "${red}=========================================${nc}"
    echo "User           | TTY | Login From | Login Time"
    echo -e "${red}-----------------------------------------${nc}"
    
    # Use 'who' or 'w' to list active standard SSH sessions (pts sessions)
    who | awk '{print $1 " | " $2 " | " $5 " | " $4}' | column -t -s '|'
    
    echo -e "${red}=========================================${nc}"
    echo ""

    # --- Dropbear/SSH (Process Method) ---
    # This catches users that might not show up in 'who' (e.g., proxied sessions)
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}    Dropbear & Proxy Sessions (w/ ps) ${nc}"
    echo -e "${red}=========================================${nc}"
    echo "PID   | User           | Login Type"
    echo -e "${red}-----------------------------------------${nc}"

    # Search for active authenticated sessions (sshd: user@ or dropbear processes)
    ps aux | grep -E 'sshd:.+@|dropbear' | grep -v grep | while read -r line; do
        PID=$(echo "$line" | awk '{print $2}')
        USER=$(echo "$line" | awk '{print $1}')
        CMD=$(echo "$line" | awk '{for (i=11; i<=NF; i++) printf "%s ", $i}')
        
        # Determine the connection type
        if [[ "$CMD" =~ ^sshd:.+@ ]]; then
            TYPE="OpenSSH Proxy"
        elif [[ "$CMD" =~ dropbear ]]; then
            TYPE="Dropbear"
        else
            continue
        fi
        
        # Only show sessions from actual users (UID >= 1000)
        if [[ $(id -u "$USER" 2>/dev/null) -ge 1000 ]]; then
            printf "%-5s | %-14s | %s\n" "$PID" "$USER" "$TYPE"
        fi
    done
    echo -e "${red}=========================================${nc}"
    echo ""
}

# Function to check and display OpenVPN sessions
check_openvpn_sessions() {
    # Helper to parse OpenVPN status log
    parse_openvpn_log() {
        local log_file=$1
        if [ -f "$log_file" ]; then
             # OpenVPN status logs often contain this line when running
             if grep -q "^CLIENT_LIST" "$log_file"; then
                echo -e "${red}=========================================${nc}"
                echo -e "${blue}      OpenVPN $(basename "$log_file" | cut -d '-' -f 2 | cut -d '.' -f 1 | tr '[:lower:]' '[:upper:]') Active Logins ${nc}"
                echo -e "${red}=========================================${nc}"
                echo "Username   |  IP Address   |  Connected Since"
                echo -e "${red}-----------------------------------------${nc}"
                
                # Extract client list, cutting relevant fields
                grep -w "^CLIENT_LIST" "$log_file" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g'
                
                echo -e "${red}=========================================${nc}"
                echo ""
            fi
        fi
    }
    
    parse_openvpn_log "$OVPN_STATUS_TCP"
    parse_openvpn_log "$OVPN_STATUS_UDP"
}


# --- Main Menu Logic ---
clear
echo -e "${red}=========================================${nc}"
echo -e "${blue}           SSH & VPN MENU          ${nc}"
echo -e "${red}=========================================${nc}"
echo -e " [1] View Active SSH/Dropbear/OpenVPN Sessions"
echo -e " [2] Check Multi-Login Limit Violations Log"
echo -e " [x] Exit to Main Menu (m-sshovpn)"
echo -e "${red}=========================================${nc}"
echo ""
read -p "Select an option [1-2 or x]: " opt

case $opt in
    1)
        check_ssh_dropbear_sessions
        check_openvpn_sessions
        return_to_menu
    ;;
    2)
        clear
        echo -e "${red}=========================================${nc}"
        echo -e "${blue}       MULTI-LOGIN VIOLATIONS       ${nc}"
        echo -e "${red}=========================================${nc}"
        if [ -e "$LOG_LIMIT_FILE" ]; then
            echo "Time - Username - Number of Sessions Killed"
            echo -e "${red}=========================================${nc}"
            # Display last 50 lines for quick viewing
            tail -n 50 "$LOG_LIMIT_FILE"
        else
            echo "No kill log file found at $LOG_LIMIT_FILE."
            echo "The AutoKill script may not be installed or has not detected any violations."
        fi
        echo -e "${red}=========================================${nc}"
        return_to_menu
    ;;
    x)
        clear
        # Execute the presumed main menu function
        m-sshovpn 2>/dev/null || exit 0
    ;;
    *)
        echo "Invalid option! Returning to menu."
        sleep 1
        $0 # Rerun the script
    ;;
esac