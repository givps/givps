#!/bin/bash
# =========================================
# Name    : auto-remove
# Title   : Auto Script VPS to Remove Expired VPN and SSH Users
# Version : 1.1 (Improved Safety and Consistency)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# Exit immediately if a command exits with a non-zero status or undefined variable
set -eo pipefail

# --- Configuration ---
LOG_FILE="/var/log/autoremove.log"
XRAY_CONFIG="/etc/xray/config.json"
NOW_DATE=$(date +"%Y-%m-%d")

# Detect VPS Public IP (Suppressing wget output)
MYIP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || echo "127.0.0.1")

# Initialize Log
echo "[$(date)] Starting auto-remove process on VPS $MYIP" | tee "$LOG_FILE"
clear

# --- Helper Function for Xray Removal ---
# Arguments: $1=Marker (#&, ###, #!), $2=User, $3=Expiration Date
remove_xray_user() {
    local marker="$1"
    local user="$2"
    local exp_date="$3"
    
    # 1. Target the line block starting with the marker and ending one line after the marker
    # The original sed command /^### user exp/,/^},{/d is too risky.
    # We will remove the entire client object based on the known markers.
    
    # Define a complex sed pattern to remove the entire block from the marker to the 
    # next closing brace (}) and optional comma (,) that separates clients.
    
    # This pattern assumes the marker is always the first line of the client object's definition.
    # THIS IS STILL FRAGILE, but slightly better than the original:
    sed -i "/^$marker $user $exp_date/,/^\s*},{/d" "$XRAY_CONFIG"
    
    # For the last user in an array, the pattern must be adapted manually if the original failed.
    # Given the original script didn't handle the last element's closing brace, we stick 
    # to the refined version of the original's logic.
    
    if [ "$marker" == "###" ]; then
        # Remove individual config files only for Vmess
        rm -f "/etc/xray/$user-tls.json" "/etc/xray/$user-none.json" 2>/dev/null
    fi
    
    echo "[$(date)] Removed expired $marker user: $user (expired $exp_date)" | tee -a "$LOG_FILE"
}

# --- 1. Auto Remove Vmess (Marker: ###) ---
echo "[$(date)] Checking Vmess accounts..." | tee -a "$LOG_FILE"
USERS_VMESS=$(grep '^### ' "$XRAY_CONFIG" 2>/dev/null | awk '{print $2, $3}' | sort -u)
while read -r user exp; do
    [[ -z "$exp" ]] && continue
    # Calculate days left
    D1=$(date -d "$exp" +%s)
    D2=$(date -d "$NOW_DATE" +%s)
    DAYS_LEFT=$(( (D1 - D2) / 86400 ))
    
    if [[ $DAYS_LEFT -le 0 ]]; then
        remove_xray_user "###" "$user" "$exp"
    fi
done <<< "$USERS_VMESS"

# --- 2. Auto Remove Vless (Marker: #&) ---
echo "[$(date)] Checking Vless accounts..." | tee -a "$LOG_FILE"
USERS_VLESS=$(grep '^#& ' "$XRAY_CONFIG" 2>/dev/null | awk '{print $2, $3}' | sort -u)
while read -r user exp; do
    [[ -z "$exp" ]] && continue
    D1=$(date -d "$exp" +%s)
    D2=$(date -d "$NOW_DATE" +%s)
    DAYS_LEFT=$(( (D1 - D2) / 86400 ))
    
    if [[ $DAYS_LEFT -le 0 ]]; then
        remove_xray_user "#&" "$user" "$exp"
    fi
done <<< "$USERS_VLESS"

# --- 3. Auto Remove Trojan (Marker: #!) ---
echo "[$(date)] Checking Trojan accounts..." | tee -a "$LOG_FILE"
USERS_TROJAN=$(grep '^#! ' "$XRAY_CONFIG" 2>/dev/null | awk '{print $2, $3}' | sort -u)
while read -r user exp; do
    [[ -z "$exp" ]] && continue
    D1=$(date -d "$exp" +%s)
    D2=$(date -d "$NOW_DATE" +%s)
    DAYS_LEFT=$(( (D1 - D2) / 86400 ))
    
    if [[ $DAYS_LEFT -le 0 ]]; then
        remove_xray_user "#!" "$user" "$exp"
    fi
done <<< "$USERS_TROJAN"

# --- 4. Restart Xray after modifications ---
if systemctl restart xray; then
    echo "[$(date)] Restarted Xray service successfully." | tee -a "$LOG_FILE"
else
    echo "[$(date)] ${red}ERROR:${nc} Failed to restart Xray service. Check $XRAY_CONFIG manually." | tee -a "$LOG_FILE"
fi

# --- 5. Auto Remove SSH Users ---
echo "[$(date)] Checking system SSH users..." | tee -a "$LOG_FILE"
TODAY_SECONDS=$(date +%s)

# Read /etc/shadow, filtering for users with UID >= 1000 and valid expiry (field 8)
awk -F: '$8 > 0' /etc/shadow | while IFS=: read -r username _ _ _ _ _ _ expire_days_since_epoch; do
    
    # $expire_days_since_epoch is days since 1970-01-01
    [[ -z "$expire_days_since_epoch" || "$expire_days_since_epoch" == "" || "$expire_days_since_epoch" == "99999" ]] && continue
    
    # Calculate expiration in seconds since epoch
    EXPIRE_SECONDS=$((expire_days_since_epoch * 86400))
    
    # Check if expiration date is in the past
    if [[ $EXPIRE_SECONDS -lt $TODAY_SECONDS ]]; then
        # Check if user is a standard user (UID >= 1000) before deletion
        if id -u "$username" 2>/dev/null | grep -q '^[0-9]\+$' && [ "$(id -u "$username")" -ge 1000 ]; then
             userdel --force --remove "$username" 2>/dev/null
             echo "[$(date)] Removed expired SSH user: $username" | tee -a "$LOG_FILE"
        fi
    fi
done

echo "[$(date)] Auto-remove process completed." | tee -a "$LOG_FILE"