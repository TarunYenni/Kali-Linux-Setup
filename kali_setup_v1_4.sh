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
      echo "Unknown option: $1"
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
  echo "Checking prerequisites..."

  # Must run as root/sudo
  if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges. Exiting."
    exit 1
  fi

  # Ensure essential tools
  essential_tools=(git wget curl dmidecode)
  for tool in "${essential_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      echo "Installing required tool '$tool'..."
      apt-get install -y -q "$tool"
    fi
  done

  echo "All prerequisites are met."
}

check_prerequisites

###############################################################################
# 4. Adjust Ownership for /opt (Always Execute)
###############################################################################

echo "Granting ownership of /opt and its contents to $CURRENT_USER..."
chown "$CURRENT_USER":"$CURRENT_USER" /opt || true
# The wildcard can fail if /opt/* doesn't exist, so ignore errors
chown "$CURRENT_USER":"$CURRENT_USER" /opt/* 2>/dev/null || true

###############################################################################
# 5. Non-Interactive Service Restarts - Remove needrestart Temporarily
###############################################################################

NEEDRESTART_CONF="/etc/needrestart/needrestart.conf"
NEEDRESTART_BACKUP="/tmp/needrestart.conf.bak"

# Backup current needrestart.conf if it exists
if [ -f "$NEEDRESTART_CONF" ]; then
  echo "Backing up existing needrestart config to $NEEDRESTART_BACKUP"
  cp "$NEEDRESTART_CONF" "$NEEDRESTART_BACKUP"
fi

echo "Purging 'needrestart' to suppress any 'relogin/restart required' pop-ups..."
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
        read -r -p "Enter your GitHub username: " GITHUB_USERNAME
        read -r -s -p "Enter your personal access token: " GITHUB_TOKEN
        echo  # move to next line after -s prompt
    fi

    # Check if repo is already present
    if [ -d "$DEST_DIR/.git" ]; then
        echo "Private repository already exists in $DEST_DIR. Pulling the latest changes..."
        cd "$DEST_DIR" && sudo -u "$CURRENT_USER" git pull
    else
        echo "Cloning the private repository into $DEST_DIR..."
        sudo -u "$CURRENT_USER" bash -c "git clone 'https://$GITHUB_USERNAME:$GITHUB_TOKEN@$REPO_URL' '$DEST_DIR'"
    fi
}

###############################################################################
# 7. Clone Both Repos (Solved_Boxes_Data + My_Pentest_Kit)
###############################################################################

do_repos() {
  echo "----- Cloning Both Private Repos -----"
  clone_private_repo "$SOLVED_BOXES_REPO" "$SOLVED_BOXES_DEST"
  clone_private_repo "$PENTEST_KIT_REPO" "$PENTEST_KIT_DEST"
}

###############################################################################
# 8. Pimpmykali Setup
###############################################################################

do_pmpk() {
  echo "----- PimpmyKali Setup -----"

  # Clone or update pimpmykali
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Pimpmykali repository already exists in $INSTALL_DIR. Pulling the latest changes..."
    cd "$INSTALL_DIR" && sudo -u "$CURRENT_USER" git pull
  else
    echo "Cloning the pimpmykali repository into $INSTALL_DIR..."
    sudo -u "$CURRENT_USER" git clone "$REPO_URL" "$INSTALL_DIR"
  fi

  # Run pimpmykali with N->Y input
  echo "Running pimpmykali with option N..."
  cd "$INSTALL_DIR"
  chmod +x pimpmykali.sh
  echo -e "N\nY" | ./pimpmykali.sh
}

###############################################################################
# 9. Tools Installation
###############################################################################

do_tools() {
  echo "----- Installing Additional Tools -----"

  # Tools to be installed
  tools=(
    faketime
    vs-code
    linux-exploit-suggester
    bloodhound.py
    thunderbird
    jq
    rlwrap
    seclists
    curl
    dnsrecon
    enum4linux
    feroxbuster
    gobuster
    impacket-scripts
    nbtscan
    nikto
    nmap
    onesixtyone
    oscanner
    redis-tools
    smbclient
    smbmap
    snmp
    sslscan
    sipvicious
    tnscmd10g
    whatweb
    wkhtmltopdf
    python3-venv
    libmnl
    libmnl-dev
    libnftnl
    libnftnl-dev
    libgconf-2-4
    peass
    tmux
    awscli
    fzf
    libreoffice
    zsh-autosuggestions
    remmina
    remmina-plugin-rdp
    remmina-plugin-secret
  )

  for tool in "${tools[@]}"; do
    echo "Installing $tool..."
    apt-get install -y -q "$tool"
  done

  # Additional tool installations (Sublime Text)
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg \
    | gpg --dearmor \
    | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null

  echo "deb https://download.sublimetext.com/ apt/stable/" \
    | sudo tee /etc/apt/sources.list.d/sublime-text.list

  sudo apt-get update -q
  sudo apt-get install -y -q sublime-text

  # pipx-based tools
  pipx install arjun
  pipx install git+https://github.com/Tib3rius/AutoRecon.git
  pipx ensurepath
}

###############################################################################
# 10. Network Configuration + Restore
###############################################################################

function do_network() {
  echo "----- Network Configuration -----"

  local VIRTUALIZATION
  VIRTUALIZATION=$(sudo dmidecode | grep -i product | grep -E "VirtualBox|VMware" || true)

  # Only proceed if this is a VirtualBox environment
  if echo "$VIRTUALIZATION" | grep -iq "VirtualBox"; then
    echo "VirtualBox detected. Checking /etc/network/interfaces for existing block..."

    # Check if we've already appended the block for eth1 to avoid duplicates
    if ! grep -Fq "auto eth1" /etc/network/interfaces; then
      echo "No 'auto eth1' line found. Backing up and appending block..."

      # Backup the existing /etc/network/interfaces before changes
      mkdir -p "$BACKUP_DIR"
      if [ -f /etc/network/interfaces ]; then
        echo "Backing up /etc/network/interfaces to $BACKUP_DIR/network_interfaces.bak"
        cp /etc/network/interfaces "$BACKUP_DIR/network_interfaces.bak"
      fi

      # Append new lines for VirtualBox NAT
      sudo tee -a /etc/network/interfaces <<EOF

# Primary network interface
auto eth0
iface eth0 inet dhcp

# Secondary network interface (NAT Network)
auto eth1
iface eth1 inet dhcp
EOF
      echo "Appended VirtualBox network block to /etc/network/interfaces."

      echo "Restarting network services..."
      sudo systemctl restart networking.service
    else
      echo "It appears the VirtualBox block is already in /etc/network/interfaces."
      echo "Skipping backup and append."
    fi
  else
    echo "VMware or no virtualization detected. Skipping network configuration..."
  fi
}

function do_network_restore() {
  echo "----- Restoring Network Configuration -----"
  if [ -f "$BACKUP_DIR/network_interfaces.bak" ]; then
    echo "Restoring /etc/network/interfaces from backup..."
    cp "$BACKUP_DIR/network_interfaces.bak" /etc/network/interfaces
    echo "Restarting network services..."
    sudo systemctl restart networking.service
  else
    echo "No backup file found at $BACKUP_DIR/network_interfaces.bak."
    echo "Cannot restore network configuration."
  fi
}

###############################################################################
# 11. Zsh Configuration + Restore
###############################################################################

function do_zsh() {
  echo "----- Zsh Configuration -----"
  local ZSH_HISTORY_SOURCE="$SOLVED_BOXES_DEST/final_combined_history_01_2025.txt"
  local ZSHRC_SOURCE="$SOLVED_BOXES_DEST/latest_zshrc_01_2025"
  local ZSH_HISTORY_DEST="/home/$CURRENT_USER/.zsh_history"
  local ZSHRC_DEST="/home/$CURRENT_USER/.zshrc"

  # Create backup dir if needed
  mkdir -p "$BACKUP_DIR"

  # If .zshrc exists, back it up before overwriting
  if [ -f "$ZSHRC_DEST" ]; then
    echo "Backing up $ZSHRC_DEST to $BACKUP_DIR/zshrc.bak"
    cp "$ZSHRC_DEST" "$BACKUP_DIR/zshrc.bak"
  fi

  # We need Solved_Boxes_Data for the zsh config. If not found, clone only that repo.
  if [ ! -d "$SOLVED_BOXES_DEST/.git" ]; then
    echo "Solved_Boxes_Data not present at $SOLVED_BOXES_DEST."
    echo "Cloning it now to proceed with Zsh updates..."
    clone_private_repo "$SOLVED_BOXES_REPO" "$SOLVED_BOXES_DEST"
  fi

  # Merge zsh history
  if [ -f "$ZSH_HISTORY_SOURCE" ]; then
    echo "Merging zsh history from $ZSH_HISTORY_SOURCE into $ZSH_HISTORY_DEST..."
    cat "$ZSH_HISTORY_SOURCE" >> "$ZSH_HISTORY_DEST"
    sort -u "$ZSH_HISTORY_DEST" -o "$ZSH_HISTORY_DEST"
  else
    echo "Zsh history source file not found. Skipping history merge."
  fi

  # Overwrite .zshrc
  if [ -f "$ZSHRC_SOURCE" ]; then
    echo "Overwriting .zshrc with the latest configuration from $ZSHRC_SOURCE..."
    cp "$ZSHRC_SOURCE" "$ZSHRC_DEST"
  else
    echo "Zsh configuration file source not found. Skipping .zshrc update."
  fi

  # Make zsh changes active
  echo "Sourcing updated .zshrc..."
  sudo -u "$CURRENT_USER" zsh -c "source ~/.zshrc"
}

function do_zsh_restore() {
  echo "----- Restoring Zsh Configuration -----"
  local ZSHRC_DEST="/home/$CURRENT_USER/.zshrc"
  if [ -f "$BACKUP_DIR/zshrc.bak" ]; then
    echo "Restoring .zshrc from backup..."
    cp "$BACKUP_DIR/zshrc.bak" "$ZSHRC_DEST"
    chown "$CURRENT_USER":"$CURRENT_USER" "$ZSHRC_DEST"
    # Optionally re-source it
    sudo -u "$CURRENT_USER" zsh -c "source ~/.zshrc"
  else
    echo "No .zshrc backup found at $BACKUP_DIR/zshrc.bak."
    echo "Cannot restore zsh configuration."
  fi
}

###############################################################################
# 12. Main Execution Flow
###############################################################################

# 1) Repos first, if requested
if [ "$REPOS" = true ]; then
  do_repos
fi

# 2) Then pimpmykali, if requested
if [ "$PMPK" = true ]; then
  do_pmpk
fi

# 3) Tools
if [ "$TOOLS" = true ]; then
  do_tools
fi

# 4) Network
if [ "$NETWORK" = true ]; then
  do_network
fi

# 4a) Network Restore
if [ "$NETWORK_RESTORE" = true ]; then
  do_network_restore
fi

# 5) Zsh
if [ "$ZSH_UPDATE" = true ]; then
  do_zsh
fi

# 5a) Zsh Restore
if [ "$ZSH_RESTORE" = true ]; then
  do_zsh_restore
fi

###############################################################################
# 13. Reinstall needrestart & Restore Config
###############################################################################

echo "Reinstalling needrestart now that main tasks are complete..."
apt-get update -qq
apt-get install -y needrestart

# If we had a backup, restore it
if [ -f "$NEEDRESTART_BACKUP" ]; then
  echo "Restoring original needrestart config from backup..."
  cp "$NEEDRESTART_BACKUP" "$NEEDRESTART_CONF"
  # (Optional) Re-apply auto-restart lines if desired:
  # sed -i 's/^#*\$nrconf{restart} = .*/\$nrconf{restart} = "a";/' "$NEEDRESTART_CONF"
fi

# Final message
echo "--------------------------------------------------------------------"
echo "Script Execution Complete!"
echo "--------------------------------------------------------------------"
echo "Selected steps:"
echo "  --repos:           $REPOS"
echo "  --pmpk:            $PMPK"
echo "  --tools:           $TOOLS"
echo "  --network:         $NETWORK"
echo "  --zsh:             $ZSH_UPDATE"
echo "  --network-restore: $NETWORK_RESTORE"
echo "  --zsh-restore:     $ZSH_RESTORE"
echo "  --all:             $DO_ALL"
echo "--------------------------------------------------------------------"
echo "Done."
