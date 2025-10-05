#!/bin/bash
# =========================================
# Name    : update-menu-maintenance
# Title   : Auto VPS Script to Update Menu and Clear RAM Cache
# Version : 1.1 (Improved Safety and Functionality)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/givps/givps/master/menu"
CLEANCACHE_PATH="/usr/bin/clearcache"
MENU_PATH="/usr/bin/menu"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Execution ---
clear

echo -e "${blue}=========================================${nc}"
echo -e "${yellow}   VPS Maintenance & Menu Update Utility   ${nc}"
echo -e "${blue}=========================================${nc}"

# --- 1. Menu Update ---
echo -e "[ ${green}INFO${nc} ] Starting menu file update..."
sleep 1

# Define files to update
declare -A FILES_TO_UPDATE=(
    ["$CLEANCACHE_PATH"]="clearcache.sh"
    ["$MENU_PATH"]="menu.sh"
)

# Remove old files (safer rm calls)
rm -f debian.sh

# Download and set permissions for latest files
for local_path in "${!FILES_TO_UPDATE[@]}"; do
    remote_file="${FILES_TO_UPDATE[$local_path]}"
    echo -e "[ ${green}INFO${nc} ] Downloading: ${remote_file}..."
    if wget -q -O "$local_path" "$REPO_BASE/$remote_file"; then
        chmod +x "$local_path"
        echo -e "[ ${green}OK${nc} ] Updated: $local_path"
    else
        echo -e "[ ${red}ERROR${nc} ] Failed to download: $remote_file"
    fi
done

# --- 2. Clear RAM Cache ---
echo -e "\n[ ${green}INFO${nc} ] Clearing RAM Cache now..."
if [ -f "/proc/sys/vm/drop_caches" ]; then
    sync 2>/dev/null || true # Flush buffers
    echo 3 > /proc/sys/vm/drop_caches
    echo -e "[ ${green}OK${nc} ] RAM Cache cleared successfully."
else
    echo -e "[ ${yellow}WARN${nc} ] Cannot clear cache; /proc/sys/vm/drop_caches not found."
fi

# --- 3. Finalization and Reboot ---
echo -e "\n${red}=========================================${nc}"
echo -e "${yellow}System maintenance complete.${nc}"
echo -e "${blue}The VPS will now auto-reboot in 5 seconds to finalize changes...${nc}"
echo -e "${red}=========================================${nc}"

sleep 5
reboot