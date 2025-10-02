#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS to Manage VPN on Debian & Ubuntu Server
# Version : 1.0
# Author  : givps
# Edition : Stable Edition 1.2
# =========================================

# Usage: Run as root (reads /etc/xray/config.json and /var/log/xray/access.log)

set -u

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # Reset color

CONFIG="/etc/xray/config.json"
ACCESS_LOG="/var/log/xray/access.log"

# Temporary files
TMP_CONNECTED=$(mktemp) || exit 1
TMP_MATCHED=$(mktemp) || exit 1

cleanup() {
  rm -f "$TMP_CONNECTED" "$TMP_MATCHED"
}
trap cleanup EXIT

echo "Checking VPS and Xray files..."
if [[ ! -f "$CONFIG" ]]; then
  echo -e "${red}Error:${nc} $CONFIG not found."
  exit 1
fi

# 1) Collect users from config markers like: ### username 2025-09-19
mapfile -t USERS < <(grep -E '^### ' "$CONFIG" 2>/dev/null | awk '{print $2}' | sort -u)

# 2) Collect connected remote IPs observed from `ss` (ESTABLISHED sessions for xray)
ss -tnp state established 2>/dev/null \
  | awk '/ESTAB/ && /xray/ {print $5}' \
  | sed -E 's/^\[//; s/\]$//' \
  | sed -E 's/:[0-9]+$//' \
  | sort -u > "$TMP_CONNECTED"

echo -e "${red}=========================================${nc}"
echo -e "${blue}            Trojan Active Logins         ${nc}"
echo -e "${red}=========================================${nc}"

> "$TMP_MATCHED"

# 3) Loop through users: collect hits and last seen per IP, display only active (connected) IPs
for u in "${USERS[@]}"; do
  [[ -z "$u" ]] && continue

  declare -A IP_COUNT=()
  declare -A IP_LASTSEEN=()

  # Read user's log lines -> IP + count + last seen
  if [[ -f "$ACCESS_LOG" ]]; then
    while IFS= read -r line; do
      ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
      [[ -z "$ip" ]] && continue
      ts=$(echo "$line" | awk '{print $1" "$2" "$3}')
      IP_COUNT["$ip"]=$(( ${IP_COUNT["$ip"]:-0} + 1 ))
      IP_LASTSEEN["$ip"]="$ts"
    done < <(grep -F -- "$u" "$ACCESS_LOG" 2>/dev/null || true)
  fi

  # Show only IPs that are currently connected
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

# 4) Show "other" connected IPs that did not match any user
sort -u "$TMP_MATCHED" -o "$TMP_MATCHED"
if [[ -s "$TMP_CONNECTED" ]]; then
  echo -e "${blue}Other connected IPs (not matched to users):${nc}"
  comm -23 "$TMP_CONNECTED" "$TMP_MATCHED" | nl -ba -w2 -s'. '
else
  echo "No current established Xray connections found."
fi

echo -e "${red}=========================================${nc}"
read -n 1 -s -r -p "Press any key to return to menu..."
if command -v m-trojan >/dev/null 2>&1; then
  m-trojan
fi
