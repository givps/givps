#!/bin/bash
# =========================================
# Name    : givps
# Title   : Auto Script VPS For Create VPN on Debian & Ubuntu Server
# Version : 1.0
# Author  : gilper0x
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # No Color (reset)

CLEANER_PATH="/usr/local/bin/xray-cleaner"

# Create cleaner script
cat > $CLEANER_PATH <<'EOF'
#!/bin/bash
# =========================================
# Xray Universal Auto-Cleaner
# Author  : givps
# =========================================

CONFIG="/etc/xray/config.json"
TODAY=$(date +%s)

# Scan marker ### username exp
grep -E "^### " $CONFIG | while read -r marker; do
    USER=$(echo $marker | awk '{print $2}')
    EXP=$(echo $marker | awk '{print $3}')
    EXP_TS=$(date -d "$EXP" +%s)

    if [[ $EXP_TS -le $TODAY ]]; then
        # Remove all expired user blocks
        sed -i "/^### $USER $EXP/,/^},{/d" $CONFIG
        echo "Expired user removed: $USER ($EXP)"
    fi
done

systemctl restart xray >/dev/null 2>&1
EOF

# Set permission
chmod +x $CLEANER_PATH

# Install cron job
CRON_FILE="/etc/cron.d/xray-cleaner"
cat > $CRON_FILE <<EOF
*/30 * * * * root $CLEANER_PATH >/dev/null 2>&1
EOF

echo -e "${green}✅ Xray Universal Auto-Cleaner installed!${nc}"
echo "➡ Script : $CLEANER_PATH"
echo "➡ Cron   : $CRON_FILE (runs every 30 minutes)"
sleep 5
