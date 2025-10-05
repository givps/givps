#!/bin/bash
# =========================================
# Name    : auto-reboot-menu
# Title   : Interactive Menu for Auto-Reboot Scheduling
# Version : 1.1 (Reliability and Execution Flow Fixes)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

AUTO_REBOOT_SCRIPT="/usr/local/bin/auto_reboot"
REBOOT_LOG_FILE="/root/reboot-log.txt"
CRON_FILE="/etc/cron.d/auto_reboot"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Function to restart cron service
restart_cron() {
    echo -e "[${green}INFO${nc}] Restarting cron service..."
    if command -v systemctl >/dev/null; then
        systemctl restart cron >/dev/null 2>&1
    elif command -v service >/dev/null; then
        service cron restart >/dev/null 2>&1
    fi
}

# Create auto-reboot script if it doesn't exist
if [ ! -e "$AUTO_REBOOT_SCRIPT" ]; then
    cat > "$AUTO_REBOOT_SCRIPT" <<-EOF
#!/bin/bash
# Log the reboot event
date_str=\$(date +"%m-%d-%Y")
time_str=\$(date +"%T")
echo "Server successfully rebooted on \$date_str at \$time_str." >> "$REBOOT_LOG_FILE"
# Execute reboot
/sbin/shutdown -r now
EOF
    chmod +x "$AUTO_REBOOT_SCRIPT"
    touch "$REBOOT_LOG_FILE" # Ensure log file exists
fi

# --- Main Menu Loop ---
while true; do
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             AUTO-REBOOT MENU           ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    echo -e "${blue} 1 ${nc} Set Auto-Reboot Every 1 Hour"
    echo -e "${blue} 2 ${nc} Set Auto-Reboot Every 6 Hours"
    echo -e "${blue} 3 ${nc} Set Auto-Reboot Every 12 Hours"
    echo -e "${blue} 4 ${nc} Set Auto-Reboot Daily (00:00)"
    echo -e "${blue} 5 ${nc} Set Auto-Reboot Weekly (Sun 00:00)"
    echo -e "${blue} 6 ${nc} Set Auto-Reboot Monthly (1st day 00:00)"
    echo -e "${blue} 7 ${nc} Disable Auto-Reboot"
    echo -e "${blue} 8 ${nc} View Reboot Log"
    echo -e "${blue} 9 ${nc} Clear Reboot Log"
    echo -e ""
    echo -e "${blue} 0 ${nc} Back To Menu"
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""

    read -rp " Select menu option: " opt
    clear

    case "$opt" in
        1)
            echo "0 * * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set every 1 hour."
            ;;
        2)
            echo "0 */6 * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set every 6 hours."
            ;;
        3)
            echo "0 */12 * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set every 12 hours."
            ;;
        4)
            echo "0 0 * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set daily (Midnight)."
            ;;
        5)
            echo "0 0 * * 0 root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set weekly (Sunday Midnight)."
            ;;
        6)
            echo "0 0 1 * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set monthly (1st day Midnight)."
            ;;
        7)
            rm -f "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot disabled."
            ;;
        8)
            echo -e "${yellow} ----------------- REBOOT LOG --------------------${nc}"
            if [ -s "$REBOOT_LOG_FILE" ]; then
                cat "$REBOOT_LOG_FILE"
            else
                echo "No reboot activity found in the log."
            fi
            echo -e "${red}=========================================${nc}"
            ;;
        9)
            echo "" > "$REBOOT_LOG_FILE"
            echo -e "[${green}OK${nc}] Reboot log cleared."
            ;;
        0)
            # Call parent menu function if it exists, otherwise exit
            m-system 2>/dev/null || exit 0
            ;;
        *)
            echo -e "[${red}ERROR${nc}] Invalid option! Please select a number from 0-9."
            sleep 1
            continue
            ;;
    esac

    # Pause after execution for feedback, except when exiting
    if [[ "$opt" != "0" ]]; then
        echo -e ""
        read -n 1 -s -r -p "Press any key to return to the menu..."
    fi
done