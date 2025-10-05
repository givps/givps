#!/bin/bash
# =================================================================
# Name    : vpn-installer-core
# Title   : Auto Script VPS Installation Core for Multi-Protocol VPN
# Version : 1.1 (Robustness and Security Review)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =================================================================

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status or unset variable.
set -euo pipefail
IFS=$'\n\t' # Internal Field Separator to prevent problems with spaces in variables

# --- Colors ---
red='\e[1;31m'    # Bright Red
green='\e[0;32m'  # Green
yellow='\e[1;33m' # Bright Yellow
blue='\e[1;34m'   # Bright Blue
nc='\e[0m'        # No Color (reset)

# --- Functions ---

error_exit() {
    echo -e "${red}[FATAL]${nc} $1" >&2
    exit 1
}

warn_continue() {
    echo -e "${yellow}[WARN]${nc} $1"
}

# --- Initial Checks ---

# Root Check
if [ "${EUID}" -ne 0 ]; then
    error_exit "You need to run this script as root."
fi

# Virtualization Check
if [ "$(systemd-detect-virt)" == "openvz" ]; then
    error_exit "OpenVZ is not supported. Please use KVM/VMware based VPS."
fi

# --- Hostname Fix ---
localip=$(hostname -I | awk '{print $1}')
hostname_current=$(hostname)
if ! grep -q "$hostname_current" /etc/hosts; then
    echo "$localip $hostname_current" >> /etc/hosts || warn_continue "Failed to update /etc/hosts."
    echo -e "${green}Added $hostname_current to /etc/hosts.${nc}"
fi

# --- Folder Preparation ---
echo -e "${blue}Preparing directories and files...${nc}"
mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain
touch /etc/v2ray/domain
touch /root/domain # Ensure this exists for domain check

# --- Timezone & IPv6 Disable ---
echo -e "${blue}Setting timezone and disabling IPv6...${nc}"
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || warn_continue "Failed to disable IPv6 globally."
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

# --- Basic Tools & Dependencies ---
echo -e "${blue}Installing basic tools and dependencies...${nc}"
# Note: Adding `nginx` here to ensure it's available before Certbot step
apt update -y
apt install -y git curl wget python3 socat nginx certbot python3-certbot-nginx || error_exit "Failed to install core packages."

# --- Kernel Headers Check (Important for BBR/Optimization) ---
kernel_version=$(uname -r)
headers_pkg="linux-headers-$kernel_version"
if ! dpkg -s "$headers_pkg" >/dev/null 2>&1; then
    echo -e "${yellow}Installing missing package: $headers_pkg${nc}"
    if ! apt install -y "$headers_pkg"; then
        warn_continue "Failed to install kernel headers. This may affect kernel optimization."
    fi
fi

# --- Get VPS public IP ---
IP=$(curl -s ipv4.icanhazip.com || wget -qO- ipv4.icanhazip.com || echo "127.0.0.1")

# --- Domain Setup ---
clear
echo -e "${blue}================ VPS DOMAIN SETUP ================${nc}"
echo "Current Public IP: $IP"
echo "1) Use Random Domain (Cloudflare API)"
echo "2) Use Your Own Domain"
read -rp "Choose [1/2]: " dns

DOMAIN=""

if [[ "$dns" == "1" ]]; then
    # WARNING: HIGH SECURITY RISK - DOWNLOADING UNVERIFIED CF SCRIPT
    echo -e "${yellow}Downloading and executing external Cloudflare script...${nc}"
    wget -q https://raw.githubusercontent.com/givps/givps/master/ssh/cf -O /root/cf || error_exit "Failed to download cf script."
    chmod +x /root/cf
    bash /root/cf || error_exit "Cloudflare script failed. Check API key/zone ID."
    DOMAIN=$(cat /root/domain 2>/dev/null || echo "")
elif [[ "$dns" == "2" ]]; then
    read -rp "Enter Your Domain: " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        error_exit "Domain cannot be empty."
    fi
else
    error_exit "Invalid domain choice. Exiting."
fi

if [[ -z "$DOMAIN" || "$DOMAIN" == "127.0.0.1" ]]; then
    error_exit "Domain variable is empty or invalid after setup. Aborting SSL/Xray setup."
fi

echo "$DOMAIN" | tee /root/domain /etc/xray/domain /etc/v2ray/domain >/dev/null
echo "IP=$DOMAIN" > /var/lib/ipvps.conf
echo -e "${green}Domain set to: $DOMAIN${nc}"

# --- Install Nginx + TLS (Certbot) ---
echo -e "${blue}Starting Nginx and SSL Certificate installation...${nc}"

systemctl enable --now nginx || error_exit "Failed to enable/start Nginx."

echo -e "${green}Installing SSL Certificate for $DOMAIN...${nc}"

# IMPORTANT: Use Certbot staging environment for testing to avoid rate limits
# Remove --staging when ready for production
if ! certbot --nginx --non-interactive --agree-tos --email admin@$DOMAIN -d $DOMAIN; then
    error_exit "Certbot failed to obtain SSL certificate for $DOMAIN. Check DNS/Firewall."
fi
echo -e "${green}SSL Certificate installed successfully.${nc}"


# --- Install Services (HIGH RISK SECTION) ---
echo -e "${blue}================ INSTALLING VPN SERVICES (EXTERNAL SCRIPTS) ================${nc}"
declare -A external_scripts=(
    ["ssh-vpn"]="${red}https://raw.githubusercontent.com/givps/givps/master/ssh/ssh-vpn.sh${nc}"
    ["ins-xray"]="${red}https://raw.githubusercontent.com/givps/givps/master/xray/ins-xray.sh${nc}"
    ["insshws"]="${red}https://raw.githubusercontent.com/givps/givps/master/sshws/insshws.sh${nc}"
)

for service_name in "${!external_scripts[@]}"; do
    script_url="${external_scripts[$service_name]}"
    script_path="/root/$service_name.sh"
    echo -e "${yellow}Downloading ${service_name} script from $script_url...${nc}"
    if wget -q "$script_url" -O "$script_path"; then
        chmod +x "$script_path"
        echo -e "${green}Executing ${service_name} script...${nc}"
        if ! bash "$script_path"; then
            warn_continue "${service_name} script failed or returned an error. Partial installation may have occurred."
        fi
    else
        warn_continue "Failed to download ${service_name} script. Skipping this component."
    fi
done

# --- Auto Profile (Menu on Login) ---
cat > /root/.profile <<'END'
# Load .bashrc if it exists
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
# Clear screen and show menu on login
clear
menu
END
echo -e "${green}Login profile updated to automatically run 'menu'.${nc}"

# --- Logs Preparation ---
echo -e "${blue}Setting up user log files...${nc}"
for log in ssh vmess vless trojan shadowsocks; do
    log_file="/etc/log-create-$log.log"
    if [ ! -f "$log_file" ]; then
        echo "Log $log Account " > "$log_file"
    fi
done

# --- Final Summary and Reboot ---
clear
ip_public=$(curl -s ipv4.icanhazip.com)
LOG_FILE="log-install.txt"
echo "============================================================" | tee "$LOG_FILE"
echo "   Installation Finished! (Check individual service logs for details)" | tee -a "$LOG_FILE"
echo "   Domain     : $DOMAIN" | tee -a "$LOG_FILE"
echo "   Public IP  : $ip_public" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "   >>> EXPECTED Service & Port Range (Verify with configs)"  | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo " - OpenSSH      : 22, 110" | tee -a "$LOG_FILE"
echo " - Websocket    : 80, 443 (via Nginx/Tunnel)" | tee -a "$LOG_FILE"
echo " - Stunnel4     : 222, 777" | tee -a "$LOG_FILE"
echo " - Dropbear     : 109, 143" | tee -a "$LOG_FILE"
echo " - Badvpn       : 7100-7900" | tee -a "$LOG_FILE"
echo " - Nginx        : 81 (Redirect/WebUI)" | tee -a "$LOG_FILE"
echo " - Xray Protocols: 80, 443, gRPC (VMess, Vless, Trojan, Shadowsocks)" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "NOTE: A reboot is required to finalize kernel/service settings."
echo "Server will reboot in 10 seconds. Run 'menu' after reboot."
sleep 10
reboot