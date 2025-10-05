#!/usr/bin/env bash
# =================================================================
# Name    : accel-manager
# Title   : Unified Accelerator & System Manager
# Version : 1.1.0 (Robustness and Clarity)
# Author  : adapted/cleaned by givps & AI Assistant
# License : MIT
# =================================================================
set -euo pipefail
IFS=$'\n\t'

### -------- Configuration/Constants --------
SCRIPT_VER="1.1.0"
# Base URL for external kernel components (if used)
GITHUB_RAW_BASE="https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master"
LOGFILE="/var/log/accel-manager.log"

# Define the highest kernel version that supports the 'fq' QDisc before moving to 'cake'
KERNEL_CAKE_MIN=5

### -------- Colors & helpers --------
_GREEN="\033[0;32m"; _RED="\033[0;31m"; _YEL="\033[0;33m"; _CYAN="\033[0;36m"; _NC="\033[0m"
info()  { echo -e "${_GREEN}[INFO]${_NC} $*"; log "INFO: $*"; }
warn()  { echo -e "${_YEL}[WARN]${_NC} $*"; log "WARN: $*"; }
error() { echo -e "${_RED}[ERROR]${_NC} $*" >&2; log "ERROR: $*"; return 1; }
alert() { echo -e "${_CYAN}[ATTENTION]${_NC} $*"; }

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >>"${LOGFILE}"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
  fi
}

safe_cmd() {
  # run a command and log output to logfile.
  local cmd="$*"
  log "CMD: $cmd"
  if ! bash -c "$cmd" >>"${LOGFILE}" 2>&1; then
    error "Command failed (see ${LOGFILE}): $cmd"
    return 1
  fi
  return 0
}

# --- Check essential commands ---
if ! command -v uname >/dev/null || ! command -v sysctl >/dev/null; then
  error "Missing essential commands (uname or sysctl). Cannot proceed."
  exit 1
fi

### -------- Environment & detection --------
export DEBIAN_FRONTEND=noninteractive

detect_os() {
  # sets global variables: release, version, bit, kernel_major
  release=""
  version=""
  bit="$(uname -m)"
  kernel_major="$(uname -r | cut -d. -f1)"

  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID,,}" in
      ubuntu) release="ubuntu" ;;
      debian) release="debian" ;;
      centos | rhel) release="centos" ;;
      *) release="${ID,,}" ;;
    esac
    version="${VERSION_ID%%.*}"
  elif [[ -f /etc/redhat-release ]]; then
    release="centos"
    version="$(cut -d' ' -f3 /etc/redhat-release | cut -d'.' -f1)"
  fi
  if [[ "${bit}" != "x86_64" ]]; then bit="non-x64"; fi
}

### -------- Package helpers --------
install_prereqs() {
  info "Installing prerequisite packages..."
  local pkg_manager=""
  if command -v apt-get >/dev/null 2>&1; then
    pkg_manager="apt-get"
    safe_cmd "apt-get update -y"
    safe_cmd "apt-get install -y wget curl jq build-essential ca-certificates gnupg dirmngr lsb-release unzip linux-headers-$(uname -r)"
  elif command -v yum >/dev/null 2>&1; then
    pkg_manager="yum"
    safe_cmd "yum install -y epel-release wget curl jq gcc make ca-certificates kernel-devel kernel-headers"
  else
    error "Unknown package manager. Please install required packages (wget, curl, jq, build-essential/gcc, kernel-headers) manually."
    return 1
  fi
  info "Prerequisites installed using ${pkg_manager}."
}

### -------- Kernel helpers (instructional wrappers) --------
# NOTE: These functions provide instructions as kernel installation is highly system-dependent.
install_bbr_kernel() {
  info "Installing BBR-compatible kernel (>= 4.9 or 5.x)..."
  detect_os
  alert "KERNEL INSTALLATION REQUIRES A REBOOT AND MANUAL INTERVENTION."
  echo "--------------------------------------------------------"
  if [[ "${release}" == "ubuntu" || "${release}" == "debian" ]]; then
    echo -e "Recommendation for ${release}: Install a mainline or backport kernel (>= 5.x)."
    echo -e "  Example (Ubuntu): ${_YEL}sudo apt install linux-image-generic-hwe-${version} -y${_NC}"
    echo -e "  Example (Debian): ${_YEL}sudo apt install -t bullseye-backports linux-image-amd64${_NC}"
  elif [[ "${release}" == "centos" ]]; then
    echo -e "Recommendation for CentOS: Install ELRepo's kernel-ml (Mainline)."
    echo -e "  1. Install ELRepo: ${_YEL}yum install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm${_NC} (Adjust for your CentOS version)"
    echo -e "  2. Install Mainline: ${_YEL}yum --enablerepo=elrepo-kernel install kernel-ml -y${_NC}"
    echo -e "  3. ${_YEL}grub2-set-default 0${_NC} (to select the new kernel)"
  else
    warn "Unsupported release: ${release}. Please find a kernel >= 4.9 manually."
  fi
  echo "--------------------------------------------------------"
}

install_bbrplus_kernel() {
  warn "BBRplus kernel is a 3rd-party kernel. Installation is complex and unsupported here."
  alert "Find pre-compiled BBRplus DEB/RPM packages suitable for your OS and install them manually."
}

install_lotserver_kernel() {
  warn "LotServer (锐速) is proprietary and typically involves a commercial license."
  alert "Refer to the official LotServer (ServerSpeeder) documentation for installation."
}

### -------- Kernel Module Compilation --------
install_bbrmod_from_source() {
  info "Compiling BBR-mod (tcp_tsunami) module from source."
  if ! command -v make >/dev/null || ! command -v gcc >/dev/null; then
    error "Make or GCC not found. Install prerequisites first (Option 1)."
    return 1
  fi
  
  local tmpd
  tmpd="$(mktemp -d)"
  info "Working in temporary directory: ${tmpd}"
  
  safe_cmd "pushd ${tmpd}"

  safe_cmd "wget -q -O tcp_tsunami.c ${GITHUB_RAW_BASE}/bbr/tcp_tsunami.c"

  cat >Makefile <<EOF
obj-m:=tcp_tsunami.o
KDIR?=/lib/modules/$(uname -r)/build
PWD:=$(shell pwd)
default:
	$(MAKE) -C \$(KDIR) M=\$(PWD) modules
EOF

  info "Attempting module build..."
  if safe_cmd "make -C /lib/modules/$(uname -r)/build M=$(pwd) modules"; then
    if [[ -f tcp_tsunami.ko ]]; then
      info "Module compiled successfully."
      safe_cmd "cp -f tcp_tsunami.ko /lib/modules/$(uname -r)/kernel/net/ipv4/"
      safe_cmd "depmod -a"
      info "Module installed. Run Option 8 to enable."
    else
      error "Build succeeded but module file (tcp_tsunami.ko) not found."
    fi
  else
    error "Module build failed. Ensure kernel headers are installed."
  fi
  
  safe_cmd "popd"
  safe_cmd "rm -rf ${tmpd}"
}

### -------- Enable/Disable algorithms --------
enable_bbr() {
  info "Enabling BBR and setting QDisc..."
  detect_os
  local qdisc="fq"
  # Use cake if kernel version is >= KERNEL_CAKE_MIN (e.g., 5) and command exists
  if [[ "${kernel_major}" -ge "${KERNEL_CAKE_MIN}" ]] && command -v tc >/dev/null; then
    qdisc="cake"
  fi
  
  sysctl -w net.core.default_qdisc="${qdisc}" >/dev/null 2>&1 || warn "Failed to set QDisc: ${qdisc}"
  sysctl -w net.ipv4.tcp_congestion_control=bbr || error "BBR module not loaded or kernel is too old."

  # Persist changes
  info "Persisting BBR/QDisc settings to /etc/sysctl.conf"
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf || true
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf || true
  cat >> /etc/sysctl.conf <<-EOF
net.core.default_qdisc=${qdisc}
net.ipv4.tcp_congestion_control=bbr
EOF
  sysctl -p >/dev/null 2>&1
  info "BBR enabled with QDisc: ${qdisc}. Check status with Option 12."
}

enable_bbrplus() {
  info "Attempting to enable BBRplus..."
  sysctl -w net.core.default_qdisc=fq
  if sysctl -w net.ipv4.tcp_congestion_control=bbrplus; then
    info "BBRplus enabled."
    # Persist changes
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf || true
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf || true
    cat >> /etc/sysctl.conf <<-EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbrplus
EOF
  else
    warn "bbrplus not available on this kernel. Ensure the BBRplus kernel is installed."
  fi
  sysctl -p >/dev/null 2>&1
}

enable_bbrmod_tsunami() {
  info "Attempting to enable BBR-mod (tsunami)."
  if ! lsmod | grep -q tcp_tsunami; then
    if [[ -f /lib/modules/$(uname -r)/kernel/net/ipv4/tcp_tsunami.ko ]]; then
      info "Loading tcp_tsunami module..."
      modprobe tcp_tsunami || insmod /lib/modules/$(uname -r)/kernel/net/ipv4/tcp_tsunami.ko || error "Failed to load tsunami module."
    else
      warn "tcp_tsunami module not loaded and .ko file not found. Compile it using Option 5."
      return 1
    fi
  fi
  
  sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
  if sysctl -w net.ipv4.tcp_congestion_control=tsunami; then
    info "BBR-mod (tsunami) enabled."
    # Persist changes
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf || true
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf || true
    cat >>/etc/sysctl.conf <<-EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=tsunami
EOF
  else
    error "Failed to set congestion control to tsunami. Check module status."
  fi
  sysctl -p >/dev/null 2>&1
}

disable_acceleration() {
  info "Restoring kernel defaults (cubic/none) and removing custom entries from sysctl.conf"
  # Default back to standard for safety (cubic is standard CC, fq_codel is standard QDisc >= 4.15)
  sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1 || sysctl -w net.core.default_qdisc=none >/dev/null 2>&1
  sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true

  # Remove custom entries
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf || true
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf || true
  sysctl -p >/dev/null 2>&1
  info "Acceleration disabled. System defaults restored. Reboot to confirm old modules are unloaded."
}

### -------- System optimization --------
apply_sys_optimizations() {
  info "Applying system optimizations (sysctl + ulimit)."
  
  # Backup sysctl.conf (safe to overwrite old backups from this run)
  safe_cmd "cp -f /etc/sysctl.conf /etc/sysctl.conf.bak.$$"
  
  # Remove previous custom block to prevent duplication
  sed -i '/# Custom tuning added by accel-manager/,/net.ipv4.ip_forward = 1/d' /etc/sysctl.conf || true
  
  cat >>/etc/sysctl.conf <<'EOF'

# Custom tuning added by accel-manager
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 16384 262144 8388608
net.ipv4.tcp_wmem = 32768 524288 16777216
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 10240
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_syn_backlog = 10240
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_forward = 1
EOF
  info "Loading new sysctl settings..."
  sysctl -p >/dev/null 2>&1 || warn "sysctl -p failed. Check /etc/sysctl.conf syntax."
  
  # ulimits
  info "Setting file descriptor limits..."
  sed -i '/# Limits set by accel-manager/,/hard    nofile          1000000/d' /etc/security/limits.conf || true
  cat >>/etc/security/limits.conf <<'EOF'
# Limits set by accel-manager
* soft    nofile           1000000
* hard    nofile          1000000
EOF
  
  # Set ulimit for current shell/reboot
  if ! grep -q "ulimit -SHn 1000000" /etc/profile 2>/dev/null; then
    echo "ulimit -SHn 1000000" >>/etc/profile
    info "Added 'ulimit' to /etc/profile. Log out and back in, or run 'ulimit -SHn 1000000' manually."
  fi
  
  info "System optimizations applied. Reboot is recommended."
}

### -------- Utility operations --------
self_update() {
  info "Self-update: retrieving latest version from repo..."
  local remote_url="${GITHUB_RAW_BASE}/tcp.sh" # Assumes original script lives here
  if ! command -v curl >/dev/null; then
    error "Curl is required for self-update. Install it first."
    return 1
  fi
  
  if curl -fsSL "${remote_url}" -o /tmp/tcp.sh.new; then
    chmod +x /tmp/tcp.sh.new
    # Get current script path robustly
    local current_script="${BASH_SOURCE[0]}"
    if [[ ! -f "$current_script" ]]; then
        current_script="./$(basename "$0")" # Fallback if run via 'source' or unusual methods
    fi

    if [[ "$current_script" -ef /tmp/tcp.sh.new ]]; then
        warn "Cannot update: Source and target files are the same. Perhaps the script wasn't fully saved/moved on last update."
    else
        mv -f /tmp/tcp.sh.new "${current_script}"
        info "Script updated in place: ${current_script}. New version will be used next run."
    fi
  else
    error "Failed to fetch remote script from ${remote_url}."
  fi
}

show_status() {
  clear
  echo "==========================================="
  echo "       ACCELERATION & SYSTEM STATUS        "
  echo "==========================================="
  
  # Kernel & OS
  echo -e "${_CYAN}Kernel:${_NC} $(uname -r)"
  echo -e "${_CYAN}OS:${_NC} ${release:-unknown} ${version:-n/a} (${bit})"
  
  echo ""
  
  # Congestion Control (CC)
  local cc_status
  cc_status="$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null || echo "net.ipv4.tcp_congestion_control = (Unknown/Error)")"
  echo -e "${_CYAN}Congestion Control:${_NC}"
  echo -e "  $cc_status"
  
  # QDisc
  local qdisc_status
  qdisc_status="$(sysctl net.core.default_qdisc 2>/dev/null || echo "net.core.default_qdisc = (Unknown/Error)")"
  echo -e "${_CYAN}Default QDisc:${_NC}"
  echo -e "  $qdisc_status"
  
  # Loaded Modules
  echo ""
  echo -e "${_CYAN}Loaded Acceleration Modules:${_NC}"
  local loaded_modules
  loaded_modules="$(lsmod | egrep 'bbr|tsunami|nanqinlang|bbrplus' || true)"
  if [[ -n "$loaded_modules" ]]; then
      echo "$loaded_modules"
  else
      echo -e "  ${_RED}None found.${_NC}"
  fi
  
  echo "-------------------------------------------"
  # Sysctl Limits Check (a sample check)
  local file_limit
  file_limit="$(sysctl fs.file-max | awk '{print $NF}')"
  echo -e "${_CYAN}File Max Limit (fs.file-max):${_NC} $file_limit"
  
  echo "==========================================="
}

### -------- Menu & UI --------
main_menu() {
  while true; do
    clear
    detect_os
    echo "==========================================="
    echo " Accelerator & System Manager - v${SCRIPT_VER}"
    echo " Detected OS: ${release:-unknown} ${version:-n/a} ($(uname -m))"
    echo " Kernel Major: ${kernel_major}"
    echo " Log: ${LOGFILE}"
    echo "==========================================="
    echo " --- KERNEL & COMPONENT INSTALLATION (Requires Reboot) ---"
    echo " 1) Install prerequisites (wget, curl, gcc, headers)"
    echo " 2) Install BBR kernel (Instruction only)"
    echo " 3) Install BBRplus kernel (Instruction only)"
    echo " 4) Install LotServer (Instruction only)"
    echo " 5) Compile BBR-mod (tcp_tsunami) from source"
    echo " --- ACCELERATION ENABLING ---"
    echo " 6) Enable BBR (default kernel)"
    echo " 7) Enable BBRplus (if kernel installed)"
    echo " 8) Enable BBR-mod (tsunami) (if compiled)"
    echo " 9) Disable acceleration (restore cubic/fq_codel)"
    echo " --- SYSTEM OPTIMIZATION & UTILITIES ---"
    echo "10) Apply system optimizations (sysctl & limits)"
    echo "11) Self-update script"
    echo "12) Show acceleration status"
    echo "0) Exit"
    echo "-------------------------------------------"
    read -rp "Choose an option [0-12]: " choice
    
    # Run command and pause
    case "${choice}" in
      1) install_prereqs ;;
      2) install_bbr_kernel ;;
      3) install_bbrplus_kernel ;;
      4) install_lotserver_kernel ;;
      5) install_bbrmod_from_source ;;
      6) enable_bbr ;;
      7) enable_bbrplus ;;
      8) enable_bbrmod_tsunami ;;
      9) disable_acceleration ;;
      10) apply_sys_optimizations ;;
      11) self_update ;;
      12) show_status ;;
      0) info "Exiting."; exit 0 ;;
      *) warn "Invalid option"; sleep 1; continue ;;
    esac
    
    # Pause after every action, except for invalid input
    if [[ "${choice}" != "0" ]]; then
        read -rp "Action complete. Press ENTER to return to the menu..." _
    fi
  done
}

### -------- Entrypoint --------
require_root
mkdir -p "$(dirname "${LOGFILE}")"
touch "${LOGFILE}" 2>/dev/null || true
log "Script started (version ${SCRIPT_VER}) by $(whoami) on $(hostname)"

main_menu