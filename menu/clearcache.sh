#!/bin/bash
# =========================================
# Name    : clearcache
# Title   : Auto VPS Script to Clear RAM Cache on Debian & Ubuntu Server
# Version : 1.1 (Robustness and System Call)
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

# --- Main Execution ---
clear

echo -e "${blue}=========================================${nc}"
echo -e "${yellow}      RAM CACHE CLEAR UTILITY            ${nc}"
echo -e "${blue}=========================================${nc}"

# Check for required kernel file
if [ ! -f "/proc/sys/vm/drop_caches" ]; then
    echo -e "[ ${red}ERROR${nc} ] Kernel parameter /proc/sys/vm/drop_caches not found."
    echo -e "This system may not support clearing caches this way."
    sleep 3
    # Call main menu function if it exists, otherwise exit
    menu 2>/dev/null || exit 1
fi

echo -e "[ ${green}INFO${nc} ] Committing cached writes to disk..."
# Use sync to flush file system buffers before clearing cache
sync 2>/dev/null || true

echo -e "[ ${green}INFO${nc} ] Clearing pagecache, dentries, and inodes (value 3)..."

# Execute cache clearing command (requires root)
if echo 3 > /proc/sys/vm/drop_caches; then
    echo -e "[ ${green}OK${nc} ] RAM Cache cleared successfully."
else
    echo -e "[ ${red}ERROR${nc} ] Failed to clear RAM Cache. Ensure the script is run as root."
fi

echo ""
echo -e "[ ${green}INFO${nc} ] Returning to menu in 2 seconds..."
sleep 2

# Call parent menu function if it exists, otherwise exit
menu 2>/dev/null || exit 0