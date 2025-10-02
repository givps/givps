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
  echo -e " [${blue}6${nc}] Restart Squid"
  echo -e " [${blue}7${nc}] Restart Nginx"
  echo -e " [${blue}8${nc}] Restart BadVPN"
  echo -e " [${blue}9${nc}] Restart Xray"
  echo -e " [${blue}10${nc}] Restart Websocket"
  echo -e " [${blue}11${nc}] Restart Trojan"
  echo ""
  echo -e " [${red}0${nc}] Back to Main Menu"
  echo -e " [x] Exit"
  echo ""
  echo -e "${red}=========================================${nc}"
  echo ""
}

restart_msg() {
  echo -e "[ ${green}OK${nc} ] $1 restarted successfully"
}

# ===== Main =====
show_header
show_menu
read -p " Select an option : " opt
clear

case $opt in
  1)
    show_header
    echo "[INFO] Restarting all services..."
    sleep 1
    /etc/init.d/ssh restart && restart_msg "OpenSSH"
    /etc/init.d/dropbear restart && restart_msg "Dropbear"
    /etc/init.d/stunnel4 restart && restart_msg "Stunnel4"
    /etc/init.d/openvpn restart && restart_msg "OpenVPN"
    /etc/init.d/fail2ban restart && restart_msg "Fail2Ban"
    /etc/init.d/cron restart && restart_msg "Cron"
    /etc/init.d/nginx restart && restart_msg "Nginx"
    /etc/init.d/squid restart && restart_msg "Squid"
    systemctl restart xray && restart_msg "Xray"
    
    # Restart BadVPN
    screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
    screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 500
    screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
    restart_msg "BadVPN"

    # Restart Websocket
    systemctl restart sshws.service ws-dropbear.service ws-stunnel.service
    restart_msg "Websocket"

    # Restart Trojan
    systemctl restart trojan-go.service
    restart_msg "Trojan"

    echo ""
    echo "[INFO] All services have been restarted!"
    ;;
  2) /etc/init.d/ssh restart && restart_msg "OpenSSH" ;;
  3) /etc/init.d/dropbear restart && restart_msg "Dropbear" ;;
  4) /etc/init.d/stunnel4 restart && restart_msg "Stunnel4" ;;
  5) /etc/init.d/openvpn restart && restart_msg "OpenVPN" ;;
  6) /etc/init.d/squid restart && restart_msg "Squid" ;;
  7) /etc/init.d/nginx restart && restart_msg "Nginx" ;;
  8) screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 && restart_msg "BadVPN" ;;
  9) systemctl restart xray && restart_msg "Xray" ;;
  10) systemctl restart sshws.service ws-dropbear.service ws-stunnel.service && restart_msg "Websocket" ;;
  11) systemctl restart trojan-go.service && restart_msg "Trojan" ;;
  0) m-system ; exit ;;
  x) exit ;;
  *) echo "Invalid option!" ; sleep 1 ;;
esac

echo ""
read -n 1 -s -r -p "Press any key to return to the system menu"
restart
