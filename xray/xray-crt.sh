#!/bin/bash
# =========================================
# Name    : renew-ssl-wildcard
# Title   : Auto Renew SSL Certificate (Wildcard/DNS Support)
# Version : 1.7 (Final - Using CF_Token, NO CF_Email)
# Author  : gilper0x & AI Assistant
# Website : https://givps.com
# License : The MIT License (MIT)
# =========================================

# --- SENSITIVE DATA ---
# WARNING: Storing keys/tokens in plain text is a security risk.
# GANTI ini dengan API Token (Bukan Global Key!) Anda dari Cloudflare
CF_Token="BnzEPlSNz6HugXhHTH_nwgN4tHzi_ItVU_jxMI5k" 
# Variabel CF_Email TIDAK DIBUTUHKAN lagi saat menggunakan CF_Token
# Variabel CF_Key TIDAK DIGUNAKAN lagi

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
nc='\e[0m'

# --- Helper ---
info() { echo -e "[ ${green}INFO${nc} ] $*"; }
warn() { echo -e "[ ${yellow}WARN${nc} ] $*"; }
error() { echo -e "[ ${red}ERROR${nc} ] $*"; exit 1; }
log_file="/var/log/renew-cert.log"

clear
info "Starting certificate renewal process (Cloudflare DNS-01 API Token Mode)..."

# --- Domain Detection ---
if [ -f /var/lib/ipvps.conf ]; then
    domain=$(grep -oP 'domain=\K.*' /var/lib/ipvps.conf | head -n1)
elif [ -f /etc/xray/domain ]; then
    domain=$(cat /etc/xray/domain)
elif [ -f /etc/v2ray/domain ]; then
    domain=$(cat /etc/v2ray/domain)
else
    error "Domain file not found! Check configuration files."
fi

[[ -z "$domain" ]] && error "Domain is empty!"

info "Domain detected: $domain"

# --- ACME and Cloudflare Credentials Check ---
if [[ ! -d /root/.acme.sh ]]; then
    error "ACME client not found at /root/.acme.sh! Please install acme.sh first."
fi

# Configuration for Cloudflare DNS API
dns_api_flag="--dns dns_cf"

# Check for required Cloudflare Token
if [[ "$CF_Token" == "BnzEPlSNz6HugXhHTH_nwgN4tHzi_ItVU_jxMI5k" ]]; then
    error "Please replace the default value in the 'CF_Token' variable with your actual Cloudflare API Token."
fi

info "Cloudflare API Token detected."

# The domain name to issue the certificate for.
if [[ "$domain" == "*."* ]]; then
    base_domain="${domain#\*.}"
    full_issue_cmd="-d $domain -d $base_domain"
    info "Validation Type: DNS-01 (Wildcard: $domain and $base_domain)"
else
    base_domain="$domain"
    full_issue_cmd="-d $domain"
    info "Validation Type: DNS-01 (Standard: $domain)"
fi

# --- Function to Install/Sync Certificate ---
install_cert() {
    local domain_name="$1"
    
    info "Installing/Syncing certificate..."
    local cert_domain="${domain_name#\*.}" 
    
    if /root/.acme.sh/acme.sh --installcert -d "$cert_domain" \
        --fullchainpath /etc/xray/xray.crt \
        --keypath /etc/xray/xray.key --ecc; then
        
        chmod 644 /etc/xray/xray.crt
        chmod 600 /etc/xray/xray.key

        # Sync to v2ray/other directories if they exist
        mkdir -p /etc/v2ray
        cp /etc/xray/xray.crt /etc/v2ray/ 2>/dev/null || true
        cp /etc/xray/xray.key /etc/v2ray/ 2>/dev/null || true

        info "Certificate installed successfully."
        return 0
    else
        warn "Failed to install certificate."
        return 1
    fi
}

# --- Initial Certificate Issuance (Main Execution) ---
info "Issuing new certificate via ACME (DNS validation)..."

# Export the embedded token for acme.sh to use
export CF_Token="$CF_Token"
# CF_Email dan CF_Key TIDAK DIEKSPOR

if /root/.acme.sh/acme.sh --issue $full_issue_cmd $dns_api_flag -k ec-256; then
    if install_cert "$domain"; then
        info "Initial certificate setup complete."
    else
        error "Failed to install certificate after successful issue!"
    fi
else
    error "Failed to issue certificate for $domain! Check Cloudflare Token permissions or DNS propagation."
fi

# Restart Xray/V2ray services
info "Restarting Xray/V2ray services..."
systemctl restart xray 2>/dev/null
systemctl restart v2ray 2>/dev/null
systemctl restart nginx 2>/dev/null 

# ========================================================
# --- AUTO-RENEWAL SCRIPT SETUP (CRON) ---
# The renewal relies on the saved ACME configuration which includes the DNS method.

renew_script="/usr/local/bin/renew-cert.sh"

cat > "$renew_script" << EOF
#!/bin/bash
# ACME Renewal Wrapper for Xray/V2Ray (Cloudflare DNS-01)
DOMAIN=""
LOG_FILE="$log_file"

# acme.sh saves the necessary DNS Token and provider info during the first successful issuance.

# 1. Detect Domain
for f in /etc/xray/domain /etc/v2ray/domain /var/lib/ipvps.conf; do
  if [[ -f "\$f" ]]; then
    if [[ "\$f" == */ipvps.conf ]]; then
      DOMAIN=\$(grep -oP 'domain=\K[^=\n]*' "\$f" 2>/dev/null | head -n1)
    else
      DOMAIN=\$(cat "\$f" 2>/dev/null | tr -d ' \t\n\r')
    fi
    [[ -n "\$DOMAIN" ]] && break
  fi
done

if [[ -z "\$DOMAIN" ]]; then
  echo "\$(date): Domain not found in any configuration file. Cannot renew." >> "\$LOG_FILE"
  exit 1
fi

# Determine base domain for installation/renewal command
CERT_DOMAIN="\${DOMAIN#\*.}" 

echo "\$(date): Starting scheduled renewal process for \$DOMAIN (Base: \$CERT_DOMAIN)..." >> "\$LOG_FILE"

# 2. Perform ACME Renewal 
if /root/.acme.sh/acme.sh --renew -d "\$CERT_DOMAIN" --ecc; then
  echo "\$(date): ACME renewal successful (or not needed yet)." >> "\$LOG_FILE"
  
  # 3. Install/Sync Certificate
  if /root/.acme.sh/acme.sh --installcert -d "\$CERT_DOMAIN" \
      --fullchainpath /etc/xray/xray.crt \
      --keypath /etc/xray/xray.key --ecc >/dev/null; then
    
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    cp /etc/xray/xray.crt /etc/v2ray/ 2>/dev/null || true
    cp /etc/xray/xray.key /etc/v2ray/ 2>/dev/null || true
    
    echo "\$(date): Certificate installed and synced successfully." >> "\$LOG_FILE"

    # 4. Restart services only on successful renewal/install
    systemctl restart xray 2>/dev/null
    systemctl restart v2ray 2>/dev/null
    systemctl restart nginx 2>/dev/null
    echo "\$(date): Services restarted." >> "\$LOG_FILE"
  else
    echo "\$(date): WARNING: Certificate install failed after ACME renewal." >> "\$LOG_FILE"
  fi
else
  echo "\$(date): ACME renewal FAILED for \$DOMAIN." >> "\$LOG_FILE"
fi
EOF

chmod +x "$renew_script"

# Setup cron (runs daily at 3 AM)
CRON_JOB="0 3 * * * root $renew_script >/dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "$renew_script"; echo "$CRON_JOB") | crontab -

info "Auto-renew cron job installed ($CRON_JOB)"
info "Log: $log_file"

# --- Return to menu ---
if declare -f m-domain >/dev/null 2>&1; then
    read -n 1 -s -r -p "Press any key to return to menu..."
    m-domain
else
    echo -e "\nDone."
fi