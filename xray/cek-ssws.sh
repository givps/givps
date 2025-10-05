#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS - Shadowsocks Active User Check
# Version : 1.2 (Optimized)
# Author  : givps & AI Assistant
# Edition : Stable Edition 1.2
# =========================================

set -u

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

USER_FILE="/etc/shadowsocks/ss-users"
ACCESS_LOG="/var/log/xray/access.log"

# --- Temporary files for optimization ---
TMP_CONNECTED=$(mktemp) || exit 1     # IPs with current ESTABLISHED connection to Xray process
TMP_LOG_DATA=$(mktemp) || exit 1      # Parsed data from access log (user|ip|timestamp|hits)
TMP_MATCHED_IP=$(mktemp) || exit 1    # IPs successfully matched to an active user

cleanup() { rm -f "$TMP_CONNECTED" "$TMP_LOG_DATA" "$TMP_MATCHED_IP"; }
trap cleanup EXIT

clear
echo "Checking VPS and Xray files..."

# Check if user file exists and has content
if [[ ! -s "$USER_FILE" ]]; then
  echo -e "${yellow}No Shadowsocks users found in $USER_FILE.${nc}"
  exit 0
fi

# 1) Get list of all known Shadowsocks user emails
mapfile -t USERS < <(awk '{print $1}' "$USER_FILE" 2>/dev/null | sort -u)

# 2) Get IPs with current established connection to Xray
echo -e "[ ${green}INFO${nc} ] Checking current connections..."
ss -tnp state established 2>/dev/null \
  | awk '/ESTAB/ && /xray/ {print $5}' \
  | sed -E 's/^\[//; s/\]$//' \
  | sed -E 's/:[0-9]+$//' \
  | sort -u > "$TMP_CONNECTED"

if [[ ! -s "$TMP_CONNECTED" ]]; then
    echo -e "${yellow}No current established Xray connections found.${nc}"
    echo -e "${red}=========================================${nc}"
    read -n 1 -s -r -p "Press any key to return to menu..."
    type m-ssws &> /dev/null && m-ssws || exit 0
fi

# 3) OPTIMIZED LOG PARSING (Single pass with awk)
# Extracts Shadowsocks (ss-ws, ss-grpc) log entries.
# Format: user_email|IP_address|timestamp_full|hits
echo -e "[ ${green}INFO${nc} ] Parsing Xray access log (single pass, may take a moment for large logs)..."
if [[ -f "$ACCESS_LOG" ]]; then
    awk -v OFS='|' -F'\t' '
        # Only process logs containing "shadowsocks"
        /shadowsocks/ {
            # $4 contains the email (user)
            user = $4;
            # $5 contains the IP
            # Clean IP from port and brackets
            ip = $5;
            gsub(/\r$/, "", ip);
            gsub(/:[0-9]+$/, "", ip);
            gsub(/\[|\]/, "", ip);

            # $1, $2, $3 contain timestamp (date time timezone)
            ts = $1 " " $2 " " $3;

            # Check if this user is in the known list (optional, but safer)
            # This requires passing USERS array to awk, which is complex.
            # We trust the log format and filter later by user.

            # Store the data: user|ip|timestamp|hits
            if (user != "" && ip != "") {
                # Update last seen time
                LAST_SEEN[user, ip] = ts;
                # Count hits
                HITS[user, ip]++;
            }
        }
        END {
            # Print all collected data
            for (key in HITS) {
                split(key, arr, SUBSEP);
                user = arr[1];
                ip = arr[2];
                print user, ip, LAST_SEEN[user, ip], HITS[user, ip];
            }
        }
    ' "$ACCESS_LOG" > "$TMP_LOG_DATA"
else
    echo -e "${yellow}Warning: Xray access log ($ACCESS_LOG) not found.${nc}"
fi

# 4) MATCHING AND DISPLAYING RESULTS
echo -e "${red}=========================================${nc}"
echo -e "${blue}        Shadowsocks Active Logins        ${nc}"
echo -e "${red}=========================================${nc}"

ACTIVE_FOUND=0

for u in "${USERS[@]}"; do
    [[ -z "$u" ]] && continue
    
    # Extract log data for this specific user
    USER_LOG_DATA=$(grep -F "$u|" "$TMP_LOG_DATA" 2>/dev/null || true)
    [[ -z "$USER_LOG_DATA" ]] && continue
    
    # Extract unique IPs seen in the log for this user
    USER_IPS_LOG=$(echo "$USER_LOG_DATA" | awk -F'|' '{print $2}' | sort -u)
    
    # Find intersection of log IPs and actively connected IPs
    ACTIVE_IPS=$(comm -12 <(echo "$USER_IPS_LOG" | sort) "$TMP_CONNECTED" 2>/dev/null || true)

    if [[ -n "$ACTIVE_IPS" ]]; then
        ACTIVE_FOUND=1
        echo -e "${blue}User:${nc} $u"
        i=1
        
        while IFS= read -r ip; do
            # Get the latest hit and timestamp for this specific IP and user
            # Find the line matching the user and IP, and extract hits/last seen
            match=$(echo "$USER_LOG_DATA" | grep -F "$u|$ip" | tail -n 1)
            
            # Extract fields: 1=user, 2=ip, 3=timestamp, 4=hits
            hits=$(echo "$match" | awk -F'|' '{print $4}' 2>/dev/null || echo "N/A")
            last=$(echo "$match" | awk -F'|' '{print $3}' 2>/dev/null || echo "N/A")
            
            printf "  %d. ${yellow}%s${nc}  (hits: %s, last seen: %s)\n" "$i" "$ip" "$hits" "$last"
            echo "$ip" >> "$TMP_MATCHED_IP"
            ((i++))
        done <<< "$ACTIVE_IPS"
        echo -e "${red}-----------------------------------------${nc}"
    fi
done

if [[ $ACTIVE_FOUND -eq 0 ]]; then
    echo -e "${yellow}No Shadowsocks users are currently connected.${nc}"
    echo -e "${red}=========================================${nc}"
else
    # 5) Display unmatched IPs
    sort -u "$TMP_MATCHED_IP" -o "$TMP_MATCHED_IP"
    echo -e "${blue}Other connected IPs (not matched to SS users):${nc}"
    comm -23 "$TMP_CONNECTED" "$TMP_MATCHED_IP" | nl -ba -w2 -s'. '
    echo -e "${red}=========================================${nc}"
fi

read -n 1 -s -r -p "Press any key to return to menu..."

if command -v m-ssws >/dev/null 2>&1; then
  m-ssws
fi