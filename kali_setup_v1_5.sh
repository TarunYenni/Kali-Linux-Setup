#!/bin/bash
#
# Usage:
#   sudo ./kali_setup.sh [OPTIONS]
#
# Options:
#   --pmpk             Only run PimpmyKali setup (N -> Y).
#   --repos            Only clone both private repos (Solved_Boxes_Data + My_Pentest_Kit).
#   --tools            Only install the additional tools.
#   --network          Only configure network (VirtualBox detection).
#   --zsh              Only merge zsh history and overwrite .zshrc (requires Solved_Boxes_Data).
#   --network-restore  Restore /etc/network/interfaces from a previous backup.
#   --zsh-restore      Restore the original .zshrc from a previous backup.
#   --all              Run all install/modify steps (pmpk, repos, tools, network, zsh).
#   -h, --help         Show this help message and exit.
#
# Examples:
#   sudo ./kali_setup.sh --pmpk
#   sudo ./kali_setup.sh --repos --zsh
#   sudo ./kali_setup.sh --network-restore
#   sudo ./kali_setup.sh --all
#

# Colors for output
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
RESET='\e[0m'

###############################################################################
# 1. Parse Arguments
###############################################################################

PMPK=false
REPOS=false
TOOLS=false
NETWORK=false
ZSH_UPDATE=false
DO_ALL=false

NETWORK_RESTORE=false
ZSH_RESTORE=false

function usage() {
cat <<EOF
Usage:
  sudo ./kali_setup.sh [OPTIONS]

Options:
  --pmpk             Only run PimpmyKali setup (N -> Y).
  --repos            Only clone both private repos (Solved_Boxes_Data + My_Pentest_Kit).
  --tools            Only install the additional tools.
  --network          Only configure network (VirtualBox detection).
  --zsh              Only merge zsh history and overwrite .zshrc (requires Solved_Boxes_Data).
  --network-restore  Restore /etc/network/interfaces from a previous backup.
  --zsh-restore      Restore the original .zshrc from a previous backup.
  --all              Run all install/modify steps (pmpk, repos, tools, network, zsh).
  -h, --help         Show this help message and exit.

Examples:
  sudo ./kali_setup.sh --pmpk
  sudo ./kali_setup.sh --repos --zsh
  sudo ./kali_setup.sh --network-restore
  sudo ./kali_setup.sh --all
EOF
  exit 0
}

# If user runs the script with no arguments, show usage and exit
if [ $# -eq 0 ]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pmpk)
      PMPK=true
      shift
      ;;
    --repos)
      REPOS=true
      shift
      ;;
    --tools)
      TOOLS=true
      shift
      ;;
    --network)
      NETWORK=true
      shift
      ;;
    --zsh)
      ZSH_UPDATE=true
      shift
      ;;
    --network-restore)
      NETWORK_RESTORE=true
      shift
      ;;
    --zsh-restore)
      ZSH_RESTORE=true
      shift
      ;;
    --all)
      DO_ALL=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}[ERROR] Unknown option: $1${RESET}"
      usage
      ;;
  esac
done

# If --all is chosen, set all flags to true (except the restore flags remain independent)
if [ "$DO_ALL" = true ]; then
  PMPK=true
  REPOS=true
  TOOLS=true
  NETWORK=true
  ZSH_UPDATE=true
fi

###############################################################################
# 2. Define Variables
###############################################################################

REPO_URL="https://github.com/Dewalt-arch/pimpmykali.git"
INSTALL_DIR="/opt/pimpmykali"
CURRENT_USER=$(logname)

BACKUP_DIR="/opt/restore_configuration_kali"

# Private Repos
SOLVED_BOXES_REPO="github.com/TarunYenni/Solved_Boxes_Data"
SOLVED_BOXES_DEST="/home/$CURRENT_USER/Desktop/Solved_Boxes_Data"

PENTEST_KIT_REPO="github.com/TarunYenni/My_Pentest_Kit"
PENTEST_KIT_DEST="/opt/My_Pentest_Kit"

###############################################################################
# 3. Prerequisite Checks (Always Execute)
###############################################################################

check_prerequisites() {
  echo -e "${CYAN}[INFO] Checking prerequisites...${RESET}"

  # Must run as root/sudo
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This script must be run with sudo privileges. Exiting.${RESET}"
    exit 1
  fi

  # Ensure essential tools
  essential_tools=(git wget curl dmidecode)
  for tool in "${essential_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      echo -e "${YELLOW}[WARN] Installing required tool: $tool${RESET}"
      apt-get install -y -q "$tool"
    fi
  done

  echo -e "${GREEN}[SUCCESS] All prerequisites are met.${RESET}"
}

check_prerequisites

###############################################################################
# 4. Adjust Ownership for /opt (Always Execute)
###############################################################################

echo -e "${CYAN}[INFO] Granting ownership of /opt and its contents to $CURRENT_USER...${RESET}"
chown "$CURRENT_USER":"$CURRENT_USER" /opt || true
chown "$CURRENT_USER":"$CURRENT_USER" /opt/* 2>/dev/null || true

###############################################################################
# 5. Non-Interactive Service Restarts - Remove needrestart Temporarily
###############################################################################

NEEDRESTART_CONF="/etc/needrestart/needrestart.conf"
NEEDRESTART_BACKUP="/tmp/needrestart.conf.bak"

# Backup current needrestart.conf if it exists
if [ -f "$NEEDRESTART_CONF" ]; then
  echo -e "${CYAN}[INFO] Backing up existing needrestart config to $NEEDRESTART_BACKUP${RESET}"
  cp "$NEEDRESTART_CONF" "$NEEDRESTART_BACKUP"
fi

echo -e "${YELLOW}[WARN] Purging 'needrestart' to suppress pop-ups...${RESET}"
apt-get purge -y needrestart || true
apt-get autoremove -y

###############################################################################
# 6. Helper: Clone a Specific Private Repository
###############################################################################

clone_private_repo() {
  local REPO_URL="$1"
  local DEST_DIR="$2"

  # If GitHub creds not exported, prompt the user
  if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    read -r -p "$(echo -e "${YELLOW}Enter your GitHub username: ${RESET}")" GITHUB_USERNAME
    read -r -s -p "$(echo -e "${YELLOW}Enter your personal access token: ${RESET}")" GITHUB_TOKEN
    echo  # move to next line after -s prompt
  fi

  # Check if repo is already present
  if [ -d "$DEST_DIR/.git" ]; then
    echo -e "${CYAN}[INFO] Private repository already exists in $DEST_DIR. Pulling the latest changes...${RESET}"
    cd "$DEST_DIR" && sudo -u "$CURRENT_USER" git pull
  else
    echo -e "${CYAN}[INFO] Cloning the private repository into $DEST_DIR...${RESET}"
    sudo -u "$CURRENT_USER" bash -c "git clone 'https://$GITHUB_USERNAME:$GITHUB_TOKEN@$REPO_URL' '$DEST_DIR'"
  fi
}

###############################################################################
# 7. Clone Both Repos
###############################################################################

do_repos() {
  echo -e "${CYAN}[INFO] Cloning both private repositories...${RESET}"
  clone_private_repo "$SOLVED_BOXES_REPO" "$SOLVED_BOXES_DEST"
  clone_private_repo "$PENTEST_KIT_REPO" "$PENTEST_KIT_DEST"
}

###############################################################################
# 8. PimpmyKali Setup
###############################################################################

do_pmpk() {
  echo -e "${CYAN}[INFO] Setting up PimpmyKali...${RESET}"

  if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${CYAN}[INFO] Updating PimpmyKali repository...${RESET}"
    cd "$INSTALL_DIR" && sudo -u "$CURRENT_USER" git pull
  else
    echo -e "${CYAN}[INFO] Cloning PimpmyKali repository...${RESET}"
    sudo -u "$CURRENT_USER" git clone "$REPO_URL" "$INSTALL_DIR"
  fi

  echo -e "${CYAN}[INFO] Running PimpmyKali script...${RESET}"
  cd "$INSTALL_DIR"
  chmod +x pimpmykali.sh
  echo -e "N\nY" | ./pimpmykali.sh
}

###############################################################################
# 9. Tools Installation
###############################################################################

do_tools() {
  echo -e "${CYAN}[INFO] Installing additional tools...${RESET}"

  tools=(
    faketime vs-code linux-exploit-suggester bloodhound.py thunderbird
    jq rlwrap seclists curl dnsrecon enum4linux feroxbuster gobuster
    impacket-scripts nbtscan nikto nmap onesixtyone oscanner redis-tools
    smbclient smbmap snmp sslscan sipvicious tnscmd10g whatweb wkhtmltopdf
    python3-venv libmnl libmnl-dev libnftnl libnftnl-dev libgconf-2-4
    peass tmux awscli fzf libreoffice zsh-autosuggestions
  )

  for tool in "${tools[@]}"; do
    echo -e "${YELLOW}[INFO] Installing $tool...${RESET}"
    apt-get install -y -q "$tool"
  done

  echo -e "${GREEN}[SUCCESS] Tools installation completed.${RESET}"
}

###############################################################################
# 10. Network Configuration + Restore
###############################################################################

do_network() {
  echo -e "${CYAN}[INFO] Configuring network for VirtualBox...${RESET}"

  local VIRTUALIZATION
  VIRTUALIZATION=$(sudo dmidecode | grep -i product | grep -E "VirtualBox|VMware" || true)

  if echo "$VIRTUALIZATION" | grep -iq "VirtualBox"; then
    echo -e "${CYAN}[INFO] VirtualBox detected. Configuring network interfaces...${RESET}"
    if ! grep -Fq "auto eth1" /etc/network/interfaces; then
      echo -e "${CYAN}[INFO] Backing up and updating /etc/network/interfaces...${RESET}"
      mkdir -p "$BACKUP_DIR"
      cp /etc/network/interfaces "$BACKUP_DIR/network_interfaces.bak"
      sudo tee -a /etc/network/interfaces <<EOF

# Primary network interface
auto eth0
iface eth0 inet dhcp

# Secondary network interface (NAT Network)
auto eth1
iface eth1 inet dhcp
EOF
      sudo systemctl restart networking.service
    else
      echo -e "${YELLOW}[WARN] Network configuration for VirtualBox already exists. Skipping...${RESET}"
    fi
  else
    echo -e "${YELLOW}[WARN] VirtualBox not detected. Skipping network configuration...${RESET}"
  fi
}

do_network_restore() {
  echo -e "${CYAN}[INFO] Restoring network configuration...${RESET}"
  if [ -f "$BACKUP_DIR/network_interfaces.bak" ]; then
    cp "$BACKUP_DIR/network_interfaces.bak" /etc/network/interfaces
    echo -e "${GREEN}[SUCCESS] Restored network configuration.${RESET}"
    systemctl restart networking.service
  else
    echo -e "${RED}[ERROR] No backup found at $BACKUP_DIR/network_interfaces.bak. Skipping.${RESET}"
  fi
}

###############################################################################
# 11. Zsh Configuration + Restore
###############################################################################

do_zsh() {
  echo -e "${CYAN}[INFO] Configuring Zsh...${RESET}"

  local ZSH_HISTORY_SOURCE="$SOLVED_BOXES_DEST/final_combined_history_11_2025.txt"
  local ZSHRC_SOURCE="$SOLVED_BOXES_DEST/latest_zshrc_01_2025"
  local ZSH_HISTORY_DEST="/home/$CURRENT_USER/.zsh_history"
  local ZSHRC_DEST="/home/$CURRENT_USER/.zshrc"

  mkdir -p "$BACKUP_DIR"

  if [ -f "$ZSHRC_DEST" ]; then
    echo -e "${CYAN}[INFO] Backing up existing .zshrc...${RESET}"
    cp "$ZSHRC_DEST" "$BACKUP_DIR/zshrc.bak"
  fi

  if [ -f "$ZSH_HISTORY_SOURCE" ]; then
    echo -e "${CYAN}[INFO] Merging Zsh history...${RESET}"
    cat "$ZSH_HISTORY_SOURCE" >> "$ZSH_HISTORY_DEST"
    sort -u "$ZSH_HISTORY_DEST" -o "$ZSH_HISTORY_DEST"
  fi

  if [ -f "$ZSHRC_SOURCE" ]; then
    echo -e "${CYAN}[INFO] Updating .zshrc...${RESET}"
    cp "$ZSHRC_SOURCE" "$ZSHRC_DEST"
    sudo -u "$CURRENT_USER" zsh -c "source ~/.zshrc"
  fi
}

do_zsh_restore() {
  echo -e "${CYAN}[INFO] Restoring Zsh configuration...${RESET}"
  local ZSHRC_DEST="/home/$CURRENT_USER/.zshrc"
  if [ -f "$BACKUP_DIR/zshrc.bak" ]; then
    cp "$BACKUP_DIR/zshrc.bak" "$ZSHRC_DEST"
    echo -e "${GREEN}[SUCCESS] Restored Zsh configuration.${RESET}"
  else
    echo -e "${RED}[ERROR] No backup found for Zsh configuration.${RESET}"
  fi
}

###############################################################################
# 12. Main Execution Flow
###############################################################################

if [ "$REPOS" = true ]; then
  do_repos
fi

if [ "$PMPK" = true ]; then
  do_pmpk
fi

if [ "$TOOLS" = true ]; then
  do_tools
fi

if [ "$NETWORK" = true ]; then
  do_network
fi

if [ "$NETWORK_RESTORE" = true ]; then
  do_network_restore
fi

if [ "$ZSH_UPDATE" = true ]; then
  do_zsh
fi

if [ "$ZSH_RESTORE" = true ]; then
  do_zsh_restore
fi

echo -e "${GREEN}[SUCCESS] Script execution completed.${RESET}"
