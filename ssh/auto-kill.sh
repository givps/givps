#!/bin/bash
# =========================================
# Name    : autokill-menu
# Title   : Interactive Menu for AutoKill SSH/Dropbear Session Limiter
# Version : 1.2 (Hardening and UX Refinement)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

KILL_SCRIPT_PATH="/usr/local/bin/autokick" # Path of the actual killing script
CRON_FILE="/etc/cron.d/autokick"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'
Green_font_prefix="${green}"
Red_font_prefix="${red}"
Font_color_suffix="${nc}"
Info="${Green_font_prefix}[ON]${Font_color_suffix}"
Error="${Red_font_prefix}[OFF]${Font_color_suffix}"

# Detect VPS IP (Safely)
MYIP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "127.0.0.1")

# Function to safely get the current MAX session limit from the Autokill script
get_current_max() {
    if [[ -f "$KILL_SCRIPT_PATH" ]]; then
        # Look for the line 'MAX=N' (starting the line)
        local max_value
        max_value=$(grep '^MAX=' "$KILL_SCRIPT_PATH" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' | head -n 1)
        if [[ -n "$max_value" ]]; then
            echo "$max_value"
        else
            echo "1 (Default/Not Found)"
        fi
    else
        echo "N/A (Script Missing)"
    fi
}

# Function to safely set the new MAX session limit in the Autokill script
set_new_max() {
    local new_max="$1"
    if [[ -f "$KILL_SCRIPT_PATH" ]]; then
        # Check if MAX line exists, if so, replace it; otherwise, prepend it.
        if grep -q '^MAX=' "$KILL_SCRIPT_PATH"; then
            # Replace the existing MAX line
            sed -i "s/^MAX=[0-9]*/MAX=$new_max/" "$KILL_SCRIPT_PATH"
        else
            # Prepend the new MAX line to the top of the script
            # NOTE: This assumes the core script can handle variables at the top.
            echo -e "MAX=$new_max\n$(cat "$KILL_SCRIPT_PATH")" > "$KILL_SCRIPT_PATH"
        fi
        echo -e "${Green_font_prefix}[OK]${Font_color_suffix} Max session limit set to $new_max in $KILL_SCRIPT_PATH"
    else
        echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Autokill script not found at $KILL_SCRIPT_PATH! Cannot set limit."
        exit 1
    fi
}

# Function to parse and display cron interval
get_cron_interval() {
    if [[ -f "$CRON_FILE" ]]; then
        # Safely extract interval from the cron file (ignoring comments)
        local cron_line
        cron_line=$(grep -vE '^(#|$)' "$CRON_FILE" | head -n 1)
        if [[ -n "$cron_line" ]]; then
            # Extract the minute field (first column)
            local minute_field
            minute_field=$(echo "$cron_line" | awk '{print $1}')
            
            if [[ "$minute_field" =~ ^\*/([0-9]+)$ ]]; then
                echo "${BASH_REMATCH[1]}" # e.g., '5' from '*/5'
            elif [[ "$minute_field" == "*" ]]; then
                echo "1" # Assumes '*' means every minute
            else
                echo "Custom" # More complex crontab entry
            fi
        else
            echo "Invalid Cron"
        fi
    else
        echo "Disabled"
    fi
}

# --- Main Logic ---

# Get current status before running the menu
MAX_LOGIN_CURRENT=$(get_current_max)
INTERVAL_CURRENT=$(get_cron_interval)

# Determine status for display
if [[ "$INTERVAL_CURRENT" == "Disabled" ]]; then
    STS="${Error}"
else
    STS="${Info}"
fi

while true; do
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             AUTOKILL SSH MANAGER          ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e " VPS IP          : $MYIP"
    echo -e " Autokill Status : $STS"
    echo -e " Check Interval  : $INTERVAL_CURRENT minute(s)"
    echo -e " Max MultiLogin  : $MAX_LOGIN_CURRENT"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    echo -e "[1]  AutoKill Every 5 Minutes"
    echo -e "[2]  AutoKill Every 10 Minutes"
    echo -e "[3]  AutoKill Every 15 Minutes"
    echo -e "[4]  Disable AutoKill / MultiLogin"
    echo -e "[5]  Custom Interval (Minutes)"
    echo -e "[0]  Back To Menu / Exit"
    echo -e "${red}=========================================${nc}"
    echo -e ""

    read -rp "Select an option [0-5]: " AutoKill

    # Input validation for menu option
    if [[ -z "$AutoKill" || ! "$AutoKill" =~ ^[0-5]$ ]]; then
        echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Invalid option selected. Press any key to continue...${Font_color_suffix}"
        read -n 1 -s
        continue
    fi
    
    # Exit option
    if [[ "$AutoKill" == "0" ]]; then
        m-sshovpn 2>/dev/null || exit 0
    fi
    
    # --- Option 4: Disable ---
    if [[ "$AutoKill" == "4" ]]; then
        rm -f "$CRON_FILE" 2>/dev/null
        echo -e "❌ Autokill MultiLogin disabled."
        # No need to restart cron if we just deleted the file.
        read -n 1 -s -r -p "Press any key to return to the menu..."
        continue
    fi

    # --- Options 1, 2, 3, 5: Configure Max Login ---
    read -rp "Enter maximum number of allowed multi-login sessions (Current: $MAX_LOGIN_CURRENT): " new_max
    if [[ -z "$new_max" || ! "$new_max" =~ ^[1-9][0-9]*$ ]]; then
        echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Max login must be a positive integer (1 or higher)! Press any key to continue...${Font_color_suffix}"
        read -n 1 -s
        continue
    fi
    set_new_max "$new_max" # Set the new MAX value in the core script

    # --- Cron Setting Logic ---
    INTERVAL_TO_SET=""
    case $AutoKill in
        1)
            INTERVAL_TO_SET=5
            ;;
        2)
            INTERVAL_TO_SET=10
            ;;
        3)
            INTERVAL_TO_SET=15
            ;;
        5)
            read -rp "Enter custom interval (minutes, 1-59): " INTERVAL_TO_SET
            if [[ -z "$INTERVAL_TO_SET" || ! "$INTERVAL_TO_SET" =~ ^[1-5]?[0-9]$ ]]; then
                echo -e "${Red_font_prefix}[Error]${Font_color_suffix} Interval must be between 1 and 59 minutes! Press any key to continue...${Font_color_suffix}"
                read -n 1 -s
                continue
            fi
            ;;
    esac

    # Write the new Cron entry
    echo "# Autokill Session Limiter" > "$CRON_FILE"
    # Write the entry using the specific interval
    echo "*/$INTERVAL_TO_SET * * * * root $KILL_SCRIPT_PATH" >> "$CRON_FILE"

    echo -e "✅ Autokill set every $INTERVAL_TO_SET minutes | Max Login: $new_max"

    # Restart cron service (handles different init systems)
    if command -v systemctl >/dev/null; then
        systemctl restart cron >/dev/null 2>&1
    elif command -v service >/dev/null; then
        service cron restart >/dev/null 2>&1
    fi

    echo -e "${Green_font_prefix}[OK]${Font_color_suffix} Autokill setting applied successfully! Press any key to return to the menu...${Font_color_suffix}"
    read -n 1 -s

    # Update status variables for next loop iteration
    MAX_LOGIN_CURRENT=$(get_current_max)
    INTERVAL_CURRENT=$(get_cron_interval)
done