#!/bin/bash
# =========================================
# Name    : delete-ssh-user
# Title   : Auto Script VPS to Delete SSH User
# Version : 1.1 (Revised for Safety and Robustness)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# Detect VPS Public IP (Not strictly needed for deletion, but kept for context)
MYIP=$(wget -qO- ipv4.icanhazip.com)
clear

echo -e "${red}=========================================${nc}"
echo -e "${blue}            ⇱ DELETE SSH USER ⇲          ${nc}"
echo -e "${red}=========================================${nc}"
echo ""

# --- Ask for username ---
read -rp "🔑 Enter the SSH username to delete: " USERNAME

# --- Validation and Deletion Logic ---
if [[ -z "$USERNAME" ]]; then
    echo -e "${red}⚠️  Error: Username cannot be empty!${nc}"
elif ! id "$USERNAME" &>/dev/null; then
    echo -e "${red}❌ Error: User '$USERNAME' does not exist on this system.${nc}"
else
    # Get the User ID (UID)
    USER_UID=$(id -u "$USERNAME")
    
    # Safety Check: Prevent deletion of critical system accounts (UID < 1000)
    if [[ "$USER_UID" -lt 1000 ]]; then
        echo -e "${red}🛑 STOPPED: User '$USERNAME' has UID $USER_UID.${nc}"
        echo -e "${yellow}This appears to be a critical system account. Deletion aborted for safety.${nc}"
    else
        # --- Confirm Deletion ---
        read -rp "Are you sure you want to delete user '$USERNAME' and its home directory? (y/N): " CONFIRM
        
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            # The -r flag removes the home directory and mail spool
            if sudo userdel -r "$USERNAME" &>/dev/null; then
                echo -e "${green}✅ User '$USERNAME' (UID $USER_UID) has been deleted successfully, along with its home directory.${nc}"
            else
                echo -e "${red}❌ Fatal Error: Failed to delete user '$USERNAME'. Check logs for details.${nc}"
            fi
        else
            echo -e "${yellow}Deletion of user '$USERNAME' cancelled.${nc}"
        fi
    fi
fi

echo ""
echo -e "${red}=========================================${nc}"
read -n 1 -s -r -p "Press any key to return to the menu..."
# Execute the presumed main menu function
m-sshovpn 2>/dev/null || exit 0