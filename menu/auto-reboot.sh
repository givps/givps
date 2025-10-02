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

# Create auto-reboot script if it doesn't exist
if [ ! -e /usr/local/bin/auto_reboot ]; then
    cat > /usr/local/bin/auto_reboot <<-EOF
#!/bin/bash
date_str=\$(date +"%m-%d-%Y")
time_str=\$(date +"%T")
echo "Server successfully rebooted on \$date_str at \$time_str." >> /root/reboot-log.txt
/sbin/shutdown -r now
EOF
    chmod +x /usr/local/bin/auto_reboot
fi

# Display menu
echo -e "${red}=========================================${nc}"
echo -e "${blue}             AUTO-REBOOT MENU           ${nc}"
echo -e "${red}=========================================${nc}"
echo -e ""
echo -e "${blue} 1 ${nc} Set Auto-Reboot Every 1 Hour"
echo -e "${blue} 2 ${nc} Set Auto-Reboot Every 6 Hours"
echo -e "${blue} 3 ${nc} Set Auto-Reboot Every 12 Hours"
echo -e "${blue} 4 ${nc} Set Auto-Reboot Daily"
echo -e "${blue} 5 ${nc} Set Auto-Reboot Weekly"
echo -e "${blue} 6 ${nc} Set Auto-Reboot Monthly"
echo -e "${blue} 7 ${nc} Disable Auto-Reboot"
echo -e "${blue} 8 ${nc} View Reboot Log"
echo -e "${blue} 9 ${nc} Clear Reboot Log"
echo -e ""
echo -e "${blue} 0 ${nc} Back To Menu"
echo -e ""
echo -e "${blue} Press x or [Ctrl+C] to Exit ${nc}"
echo -e ""
echo -e "${red}=========================================${nc}"
echo -e ""

read -p " Select menu option: " opt
clear

case $opt in
1)
    echo "0 * * * * root /usr/local/bin/auto_reboot" > /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot set every 1 hour."
    ;;
2)
    echo "0 */6 * * * root /usr/local/bin/auto_reboot" > /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot set every 6 hours."
    ;;
3)
    echo "0 */12 * * * root /usr/local/bin/auto_reboot" > /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot set every 12 hours."
    ;;
4)
    echo "0 0 * * * root /usr/local/bin/auto_reboot" > /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot set daily."
    ;;
5)
    echo "0 0 * * 0 root /usr/local/bin/auto_reboot" > /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot set weekly."
    ;;
6)
    echo "0 0 1 * * root /usr/local/bin/auto_reboot" > /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot set monthly."
    ;;
7)
    rm -f /etc/cron.d/auto_reboot
    echo -e "[${green}OK${nc}] Auto-Reboot disabled."
    ;;
8)
    echo -e "${yellow} ----------------- REBOOT LOG --------------------${nc}"
    if [ -e /root/reboot-log.txt ]; then
        cat /root/reboot-log.txt
    else
        echo "No reboot activity found."
    fi
    echo -e "${red}=========================================${nc}"
    read -n 1 -s -r -p "Press any key to return..."
    auto-reboot
    ;;
9)
    echo "" > /root/reboot-log.txt
    echo -e "[${green}OK${nc}] Reboot log cleared."
    read -n 1 -s -r -p "Press any key to return..."
    auto-reboot
    ;;
0)
    m-system
    ;;
x)
    exit
    ;;
*)
    echo -e "[${red}ERROR${nc}] Invalid option!"
    sleep 1
    auto-reboot
    ;;
esac
