#!/bin/bash
# =========================================
# Name    : service-restart
# Title   : Interactive Menu for VPN/System Service Restarts
# Version : 1.1 (Systemd Compliance and Safety)
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

# --- Functions ---

# Function to safely check and restart a service via systemctl
restart_service() {
    local service_name="$1"
    
    # Check if systemctl is available and the service unit file exists
    if ! command -v systemctl >/dev/null || ! systemctl is-enabled "$service_name" >/dev/null 2>&1; then
        echo -e "[ ${yellow}SKIP${nc} ] $service_name is not installed or service unit not found. Skipping."
        return 0 # Indicate success (of skipping)
    fi

    echo -n "[INFO] Restarting $service_name..."
    if systemctl restart "$service_name" >/dev/null 2>&1; then
        echo -e "\r[ ${green}OK${nc} ] $service_name restarted successfully."
    else
        echo -e "\r[ ${red}FAIL${nc} ] $service_name failed to restart. Check logs."
    fi
}

# Function to safely restart SysVinit service as fallback
restart_sysv() {
    local sysv_path="/etc/init.d/$1"
    local service_alias="$2"
    
    if [ -f "$sysv_path" ]; then
        echo -n "[INFO] Restarting $service_alias..."
        if "$sysv_path" restart >/dev/null 2>&1; then
            echo -e "\r[ ${green}OK${nc} ] $service_alias restarted successfully."
        else
            echo -e "\r[ ${red}FAIL${nc} ] $service_alias failed to restart. Check logs."
        fi
    else
        echo -e "[ ${yellow}SKIP${nc} ] $service_alias (/etc/init.d) not found. Skipping."
    fi
}

# Function to safely restart BadVPN sessions
restart_badvpn() {
    echo -n "[INFO] Checking BadVPN status..."
    # 1. Kill all existing 'badvpn-udpgw' screens/processes
    screen -ls | grep -E '\.(badvpn)\s' | awk -F '.' '{print $1}' | xargs -r screen -S badvpn -X quit >/dev/null 2>&1
    pkill -f badvpn-udpgw >/dev/null 2>&1 || true

    # 2. Start new sessions (assuming 7100, 7200, 7300 setup)
    screen -dmS badvpn-7100 badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500 >/dev/null 2>&1
    screen -dmS badvpn-7200 badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 500 >/dev/null 2>&1
    screen -dmS badvpn-7300 badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 >/dev/null 2>&1

    # Check if at least one session is running
    if screen -ls | grep -E '\.(badvpn-)' >/dev/null; then
        echo -e "\r[ ${green}OK${nc} ] BadVPN restarted successfully (sessions 7100, 7200, 7300)."
    else
        echo -e "\r[ ${red}FAIL${nc} ] BadVPN failed to start sessions. Check 'screen' installation."
    fi
}

show_header() {
  echo -e "${red}=========================================${nc}"
  echo -e "${blue}             • RESTART MENU •             ${nc}"
  echo -e "${red}=========================================${nc}"
  echo ""
}

show_menu() {
  echo -e " [${blue}1${nc}] Restart All Services"
  echo -e " [${blue}2${nc}] Restart OpenSSH"
  echo -e " [${blue}3${nc}] Restart Dropbear"
  echo -e " [${blue}4${nc}] Restart Stunnel4"
  echo -e " [${blue}5${nc}] Restart OpenVPN"
  echo -e " [${blue}6${nc}] Restart Squid Proxy"
  echo -e " [${blue}7${nc}] Restart Nginx"
  echo -e " [${blue}8${nc}] Restart BadVPN UDPGW"
  echo -e " [${blue}9${nc}] Restart Xray (VMess/VLESS)"
  echo -e " [${blue}10${nc}] Restart Websocket Tunnels (sshws.service)"
  echo -e " [${blue}11${nc}] Restart Trojan (trojan-go.service)"
  echo ""
  echo -e " [${red}0${nc}] Back to System Menu"
  echo -e " [x] Exit"
  echo ""
  echo -e "${red}=========================================${nc}"
  echo ""
}

# --- Main Menu Loop ---
while true; do
    show_header
    show_menu
    read -rp " Select an option : " opt
    clear
    
    show_header

    case "$opt" in
        1)
            echo "[INFO] Starting full service restart..."
            sleep 1
            # Standard services (using systemctl preferred, fallback to SysV)
            restart_service ssh || restart_sysv ssh "OpenSSH"
            restart_service dropbear || restart_sysv dropbear "Dropbear"
            restart_service stunnel4 || restart_sysv stunnel4 "Stunnel4"
            restart_service openvpn || restart_sysv openvpn "OpenVPN"
            restart_service fail2ban || restart_sysv fail2ban "Fail2Ban"
            restart_service cron || restart_sysv cron "Cron"
            restart_service nginx || restart_sysv nginx "Nginx"
            restart_service squid || restart_sysv squid "Squid"
            
            # Xray and VPN specific
            restart_service xray
            restart_service trojan-go
            restart_service sshws
            restart_service ws-dropbear
            restart_service ws-stunnel
            
            # BadVPN (requires special handling)
            restart_badvpn
            
            echo ""
            echo "[INFO] All relevant services have been checked and restarted!"
            ;;
        2) restart_service ssh || restart_sysv ssh "OpenSSH" ;;
        3) restart_service dropbear || restart_sysv dropbear "Dropbear" ;;
        4) restart_service stunnel4 || restart_sysv stunnel4 "Stunnel4" ;;
        5) restart_service openvpn || restart_sysv openvpn "OpenVPN" ;;
        6) restart_service squid || restart_sysv squid "Squid" ;;
        7) restart_service nginx || restart_sysv nginx "Nginx" ;;
        8) restart_badvpn ;;
        9) restart_service xray ;;
        10) 
            # Assuming these are the WebSocket services
            restart_service sshws
            restart_service ws-dropbear
            restart_service ws-stunnel
            ;;
        11) restart_service trojan-go ;;
        0) 
            # Call parent menu function if it exists, otherwise exit
            m-system 2>/dev/null || exit 0 
            ;;
        x|X) exit 0 ;;
        *) echo -e "${red}Invalid option!${nc}" ; sleep 1 ;;
    esac

    echo ""
    read -n 1 -s -r -p "Press any key to return to the restart menu..."
done