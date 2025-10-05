#!/bin/bash
# =========================================
# Name    : xray-universal-cleaner
# Title   : Xray Universal Auto-Cleaner
# Version : 1.2 (Revised)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
nc='\e[0m'

CLEANER_PATH="/usr/local/bin/xray-cleaner"
USER_FILE="/etc/xray/trial-users"
CONFIG_FILE="/etc/xray/config.json"
LOG_FILE="/var/log/xray-cleaner.log"

# --- Pre-Check: Install jq ---
if ! command -v jq &> /dev/null; then
  echo -e "${yellow}Installing jq for JSON manipulation...${nc}"
  apt update && apt install -y jq || { echo -e "${red}❌ Failed to install jq! Cleaner may not function.${nc}"; }
fi

# --- Create the dedicated cleaner script ---
cat > "$CLEANER_PATH" << EOF
#!/bin/bash
USER_FILE="$USER_FILE"
CONFIG_FILE="$CONFIG_FILE"
LOG_FILE="$LOG_FILE"
TODAY=\$(date +%s)
RESTART_NEEDED=0

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "\$(date): ERROR: jq not found. Cannot remove users from config.json. Exiting." >> "\$LOG_FILE"
    exit 1
fi

# Create log file if not exists
touch "\$LOG_FILE"

# If user file doesn't exist, exit
[ ! -f "\$USER_FILE" ] && exit 0

# Backup user file
cp "\$USER_FILE" "\$USER_FILE.bak"

# Create new temp user file and config temp file
> "\$USER_FILE.tmp"
CONFIG_TMP="\$CONFIG_FILE.tmp"

# Process each line
while IFS= read -r line; do
    [ -z "\$line" ] && continue
    # Format: USER UUID/Password EXPIRY_DATE PROTOCOL
    set -- \$line
    USER="\$1"
    UUID_PWD="\$2"
    EXP="\$3"
    PROTOCOL="\$4" # e.g., vmess, vless, shadowsocks, trojan

    if [ -n "\$EXP" ]; then
        EXP_TS=\$(date -d "\$EXP" +%s 2>/dev/null || echo 0)
        
        if [ "\$EXP_TS" -le "\$TODAY" ] 2>/dev/null; then
            echo "\$(date): Removing expired \$PROTOCOL trial user: \$USER (Expired: \$EXP)" >> "\$LOG_FILE"
            
            # --- Remove user from config.json using jq ---
            if jq --arg u "\$USER" 'del(.inbounds[]?.settings.clients[]? | select(.email == \$u))' "\$CONFIG_FILE" > "\$CONFIG_TMP"; then
                mv "\$CONFIG_TMP" "\$CONFIG_FILE"
                RESTART_NEEDED=1
            else
                echo "\$(date): WARNING: Failed to remove \$USER from config.json. Manual cleanup required." >> "\$LOG_FILE"
                # Keep user in file if removal fails, for re-attempt
                echo "\$line" >> "\$USER_FILE.tmp"
            fi
            
        else
            # User is still valid, keep them in the file
            echo "\$line" >> "\$USER_FILE.tmp"
        fi
    else
        # Invalid format or missing expiry, keep for inspection
        echo "\$line" >> "\$USER_FILE.tmp"
    fi
done < "\$USER_FILE.bak"

# Replace with cleaned user file
mv "\$USER_FILE.tmp" "\$USER_FILE"

# Restart Xray if any configuration change occurred
if [ "\$RESTART_NEEDED" -eq 1 ]; then
    echo "\$(date): Configuration changed. Restarting Xray service." >> "\$LOG_FILE"
    systemctl restart xray >/dev/null 2>&1
else
    echo "\$(date): No expired users found or no config change needed." >> "\$LOG_FILE"
fi

exit 0
EOF

chmod +x "$CLEANER_PATH"

# Create user file if not exists
mkdir -p /etc/xray
touch "$USER_FILE"

# Install cron job
CRON_FILE="/etc/cron.d/xray-cleaner"
cat > "$CRON_FILE" <<EOF
# Auto-clean expired trial users daily at 00:00
0 0 * * * root $CLEANER_PATH >/dev/null 2>&1
EOF

chmod 644 "$CRON_FILE"

echo -e "${green}✅ Xray Universal Auto-Cleaner installed and configured!${nc}"
echo "---------------------------------------------------------"
echo "➡ Script   : $CLEANER_PATH"
echo "➡ User DB  : $USER_FILE (Must use format: USER UUID/PWD EXPIRY PROTOCOL)"
echo "➡ Log File : $LOG_FILE"
echo "➡ Cron Job : $CRON_FILE (runs daily at midnight)"
echo "---------------------------------------------------------"
echo -e "${yellow}Ensure all trial creation scripts use the format 'user uuid expiry protocol' in $USER_FILE.${nc}"
sleep 2