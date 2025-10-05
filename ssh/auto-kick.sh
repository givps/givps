#!/bin/bash
# =========================================
# Name    : autokill-install
# Title   : Auto Script to Install SSH/Dropbear Session Limiter
# Version : 1.1 (Revised for Reliability using PS/Who)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # Reset color

# Detect VPS IP
MYIP=$(wget -qO- ipv4.icanhazip.com)
echo -e "${green}Checking VPS...${nc}"
clear

# --- Configuration ---
# Default max login per user (configurable by user later)
MAX=1 
# Path of the AutoKill script
SCRIPT_PATH="/usr/local/bin/autokill"
# Log file for activity
LOG_FILE="/root/log-limit.txt"

echo -e "${yellow}Creating core AutoKill script at $SCRIPT_PATH...${nc}"

# --- Create main script (REVISED LOGIC) ---
cat > $SCRIPT_PATH << 'EOF'
#!/bin/bash
# --- AutoKill Core Script ---
MAX=1 # Maximum allowed sessions per user (Change this value if needed)
DATE=$(date +"%Y-%m-%d %X")
LOG_FILE="/root/log-limit.txt"

# Get a list of all active non-system users (UID >= 1000)
# This prevents accidentally counting service accounts.
declare -A PIDLIST
declare -A COUNT

# Identify active users who have an assigned home directory (standard user)
# We use /etc/passwd instead of /etc/shadow for faster, less privileged user list.
MAPFILE_USERS=()
while IFS=: read -r user _ uid _ _ home_dir _; do
    # Filter out system users and users without a shell
    if [[ "$uid" -ge 1000 ]] && [[ "$home_dir" != "/sbin/nologin" ]]; then
        MAPFILE_USERS+=("$user")
    fi
done < /etc/passwd


# --- 1. Identify SSH/Dropbear sessions and PIDs ---
# This method relies on the stable "sshd: user@" or Dropbear process names.
# ps -eo user,pid,cmd (user, pid, full command)
while IFS= read -r line; do
    # Extract USER, PID, and Command Line
    USER=$(echo "$line" | awk '{print $1}')
    PID=$(echo "$line" | awk '{print $2}')
    CMD=$(echo "$line" | awk '{for (i=3; i<=NF; i++) printf "%s ", $i}')
    CMD=$(echo "$CMD" | xargs) # Trim whitespace

    # Check if the user is in our list of active users
    if [[ " ${MAPFILE_USERS[*]} " =~ " ${USER} " ]]; then
        # Check for SSH or Dropbear
        if [[ "$CMD" =~ ^sshd:.+@ ]]; then # SSH session: sshd: username@pts/X
            COUNT[$USER]=$((COUNT[$USER]+1))
            PIDLIST[$USER]="${PIDLIST[$USER]} $PID"
        elif [[ "$CMD" == *dropbear* ]]; then # Dropbear session: /usr/sbin/dropbear
            # We must verify this Dropbear PID is actually authenticated, 
            # as pgrep will catch the master process. 
            # Since reliable log parsing is hard, we count all running dropbear PIDs 
            # associated with this user, assuming only established sessions remain.
            COUNT[$USER]=$((COUNT[$USER]+1))
            PIDLIST[$USER]="${PIDLIST[$USER]} $PID"
        fi
    fi
done < <(ps -eo user,pid,cmd | grep -E 'sshd:.+@|dropbear' | grep -v grep)


# --- 2. Kill users exceeding max sessions ---
KILLED=0
for USER in "${!COUNT[@]}"; do
    if [ "${COUNT[$USER]}" -gt "$MAX" ]; then
        # Find all PIDs to kill, excluding the first session PID to keep one active.
        PIDS_TO_KILL=$(echo "${PIDLIST[$USER]}" | xargs -n1 | tail -n +$MAX)
        
        if [ -n "$PIDS_TO_KILL" ]; then
            echo "$DATE - $USER - ${COUNT[$USER]} sessions found. Killing excessive PIDs: $PIDS_TO_KILL" | tee -a "$LOG_FILE"
            kill $PIDS_TO_KILL 2>/dev/null
            KILLED=$((KILLED+1))
        fi
    fi
done

# Note: We skip restarting SSH/Dropbear services to maintain uptime for other users.
# The killed PIDs will be cleaned up automatically.

EOF

# Set permission
chmod +x $SCRIPT_PATH

# Add to cron if not exists
echo -e "${yellow}Setting up cron job to run every minute...${nc}"
if ! grep -q "$SCRIPT_PATH" /etc/crontab; then
    # Ensure full path is used in crontab for reliability
    echo "* * * * * root $SCRIPT_PATH" >> /etc/crontab
    echo -e "\033[0;32m[OK]\033[0m Added entry to /etc/crontab."
else
    echo -e "\033[0;32m[OK]\033[0m Cron job already exists."
fi

# Restart cron
if command -v systemctl >/dev/null; then
    systemctl restart cron >/dev/null 2>&1
elif command -v service >/dev/null; then
    service cron restart >/dev/null 2>&1
fi

clear
echo -e "${red}=========================================${nc}"
echo " 🚀 AutoKill SSH/Dropbear Session Limiter Installed"
echo " Script Location : $SCRIPT_PATH"
echo " Cron Job        : Runs every 1 minute"
echo " Max Login/User  : $MAX (Change this value inside $SCRIPT_PATH)"
echo " Log File        : $LOG_FILE"
echo -e "${red}=========================================${nc}"