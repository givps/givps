#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS to Manage VPN on Debian & Ubuntu Server
# Version : 1.0
# Author  : gilper0x
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# Usage   : Run as root (reads /etc/xray/config.json and /var/log/xray/access.log)

set -u

# --- Colors ---
red='\e[1;31m'    # Bright red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright yellow
blue='\e[1;34m'   # Bright blue
nc='\e[0m'        # Reset color

CONFIG="/etc/xray/config.json"
ACCESS_LOG="/var/log/xray/access.log"

# Temporary files (will be removed on exit)
TMP_CONNECTED=$(mktemp) || exit 1
TMP_MATCHED=$(mktemp) || exit 1

cleanup() {
  rm -f "$TMP_CONNECTED" "$TMP_MATCHED"
}
trap cleanup EXIT

echo "Checking VPS and Xray configuration..."
if [[ ! -f "$CONFIG" ]]; then
  echo -e "${red}Error:${nc} $CONFIG not found."
  exit 1
fi

# 1) Collect users from config markers like: ### username 2025-09-19 or #### username ...
mapfile -t USERS < <(grep -E '^#{3,4} ' "$CONFIG" 2>/dev/null | awk '{print $2}' | sort -u)

# 2) Collect currently connected remote IPs from xray process (ESTABLISHED sessions)
ss -tnp state established 2>/dev/null \
  | awk '/ESTAB/ && /xray/ {print $5}' \
  | sed -E 's/^\[//; s/\]$//' \
  | sed -E 's/:[0-9]+$//' \
  | sed -E 's/^::ffff://' \
  | sort -u > "$TMP_CONNECTED"

echo -e "${red}=========================================${nc}"
echo -e "${blue}           VLESS Active Logins          ${nc}"
echo -e "${red}=========================================${nc}"

> "$TMP_MATCHED"

if [[ ${#USERS[@]} -eq 0 ]]; then
  echo -e "${yellow}No VLESS users found in config markers (### or ####).${nc}"
fi

# 3) Loop through users: count hits and last seen per IP, show only active (connected) IPs
for u in "${USERS[@]}"; do
  [[ -z "$u" ]] && continue

  declare -A IP_COUNT=()
  declare -A IP_LASTSEEN=()

  # Read user's log lines, extract IPv4 addresses and timestamps
  if [[ -f "$ACCESS_LOG" ]]; then
    while IFS= read -r line; do
      ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
      [[ -z "$ip" ]] && continue
      ts=$(echo "$line" | awk '{if (NF>=3) {print $1" "$2" "$3} else {print $1}}')
      IP_COUNT["$ip"]=$(( ${IP_COUNT["$ip"]:-0} + 1 ))
      IP_LASTSEEN["$ip"]="$ts"
    done < <(grep -F -- "$u" "$ACCESS_LOG" 2>/dev/null || true)
  fi

  # Find intersection with currently connected IPs
  if [[ ${#IP_COUNT[@]} -gt 0 ]]; then
    mapfile -t USER_IPS <<< "$(printf "%s\n" "${!IP_COUNT[@]}" | sort)"
    mapfile -t ACTIVE_IPS <<< "$(comm -12 <(printf "%s\n" "${USER_IPS[@]}" | sort) "$TMP_CONNECTED")"
  else
    ACTIVE_IPS=()
  fi

  if [[ ${#ACTIVE_IPS[@]} -gt 0 ]]; then
    echo -e "${blue}User:${nc} $u"
    i=1
    for ip in "${ACTIVE_IPS[@]}"; do
      hits=${IP_COUNT[$ip]:-0}
      last=${IP_LASTSEEN[$ip]:-"N/A"}
      printf "  %d. %s  (hits: %s, last seen: %s)\n" "$i" "$ip" "$hits" "$last"
      echo "$ip" >> "$TMP_MATCHED"
      ((i++))
    done
    echo -e "${red}=========================================${nc}"
  fi
done

# 4) Show "other" connected IPs that are not linked to any user
sort -u "$TMP_MATCHED" -o "$TMP_MATCHED"
if [[ -s "$TMP_CONNECTED" ]]; then
  echo -e "${blue}Other connected IPs (not matched to users):${nc}"
  comm -23 "$TMP_CONNECTED" "$TMP_MATCHED" | nl -ba -w2 -s'. '
else
  echo "No active established xray connections found."
fi

echo -e "${red}=========================================${nc}"
read -n 1 -s -r -p "Press any key to return to menu..."

# Return to menu if available
if command -v m-vless >/dev/null 2>&1; then
  m-vless
fi
