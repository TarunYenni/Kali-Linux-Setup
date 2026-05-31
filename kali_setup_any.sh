#!/bin/bash
#
# Usage:
#   sudo ./kali_setup.sh [OPTIONS]
#
# Options:
#   --pmpk             Only run PimpmyKali setup (N -> Y).
#   --repos            Only clone both private repos (Dependences + My_Pentest_Kit).
#   --tools            Only install the additional tools.
#   --network          Only configure network (VirtualBox detection).
#   --zsh              Only merge zsh history and overwrite .zshrc (requires Dependences).
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

# Catch unset variables and broken pipes early. We deliberately do NOT use
# 'set -e' so that one failed package install does not abort the whole run.
set -uo pipefail

# Make every apt/dpkg call non-interactive so unattended runs never hang.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

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
  --repos            Only clone both private repos (Dependences + My_Pentest_Kit).
  --tools            Only install the additional tools.
  --network          Only configure network (VirtualBox detection).
  --zsh              Only merge zsh history and overwrite .zshrc (requires Dependences).
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
CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-root}")

BACKUP_DIR="/opt/restore_configuration_kali"

# VirtualBox network config lives in its own drop-in so enabling/restoring it is
# just creating/deleting one file, instead of editing the main interfaces file.
NETWORK_DROPIN="/etc/network/interfaces.d/vbox-kali-setup.cfg"

# Private Repos
SOLVED_BOXES_REPO="github.com/TarunYenni/Dependences.git"
SOLVED_BOXES_DEST="/home/$CURRENT_USER/Desktop/Dependences"

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

  # Refresh package lists once per run so later installs do not fail on stale
  # metadata (especially when a single --tools/--repos step is run on its own).
  echo -e "${CYAN}[INFO] Refreshing package lists...${RESET}"
  apt-get update -q || echo -e "${YELLOW}[WARN] apt-get update reported errors; continuing.${RESET}"

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
# 5. Non-Interactive Service Restarts - Silence needrestart (restored on exit)
###############################################################################

# Instead of purging needrestart (which left the system permanently altered and
# a dead /tmp backup behind), drop in a temporary override that auto-answers its
# restart prompts. A trap removes it on ANY exit, so the system is left as found.
NEEDRESTART_DROPIN="/etc/needrestart/conf.d/00-kali-setup-noninteractive.conf"

cleanup() {
  if [ -f "$NEEDRESTART_DROPIN" ]; then
    rm -f "$NEEDRESTART_DROPIN"
    echo -e "${CYAN}[INFO] Restored needrestart configuration.${RESET}"
  fi
}
trap cleanup EXIT

if [ -d /etc/needrestart ]; then
  echo -e "${YELLOW}[WARN] Temporarily silencing 'needrestart' service-restart pop-ups...${RESET}"
  mkdir -p /etc/needrestart/conf.d
  printf '$nrconf{restart} = "a";\n$nrconf{kernelhints} = 0;\n' > "$NEEDRESTART_DROPIN"
else
  echo -e "${CYAN}[INFO] needrestart not present; nothing to silence.${RESET}"
fi

###############################################################################
# 6. Helper: Clone a Specific Private Repository
###############################################################################

clone_private_repo() {
  local REPO_URL="$1"
  local DEST_DIR="$2"

  # If GitHub creds not exported, prompt the user
  if [ -z "${GITHUB_USERNAME:-}" ] || [ -z "${GITHUB_TOKEN:-}" ]; then
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
    # Strip the embedded PAT from the stored remote so the token is not left
    # behind in plaintext inside .git/config.
    if [ -d "$DEST_DIR/.git" ]; then
      sudo -u "$CURRENT_USER" git -C "$DEST_DIR" remote set-url origin "https://$REPO_URL"
    fi
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

  # Install everything in a single transaction - far faster than one apt call
  # per package (no repeated dependency resolution / trigger processing).
  if apt-get install -y -q "${tools[@]}"; then
    echo -e "${GREEN}[SUCCESS] Tools installation completed.${RESET}"
  else
    echo -e "${YELLOW}[WARN] Batch install failed; retrying individually to isolate the offenders...${RESET}"
    local failed=()
    for tool in "${tools[@]}"; do
      apt-get install -y -q "$tool" || failed+=("$tool")
    done
    if [ "${#failed[@]}" -gt 0 ]; then
      echo -e "${RED}[WARN] These packages could not be installed: ${failed[*]}${RESET}"
    else
      echo -e "${GREEN}[SUCCESS] Tools installation completed (after individual retry).${RESET}"
    fi
  fi
}

###############################################################################
# 10. Network Configuration + Restore
###############################################################################

do_network() {
  echo -e "${CYAN}[INFO] Configuring network for VirtualBox...${RESET}"

  local VIRTUALIZATION
  VIRTUALIZATION=$(sudo dmidecode | grep -i product | grep -E "VirtualBox|VMware" || true)

  if ! echo "$VIRTUALIZATION" | grep -iq "VirtualBox"; then
    echo -e "${YELLOW}[WARN] VirtualBox not detected. Skipping network configuration...${RESET}"
    return 0
  fi

  echo -e "${CYAN}[INFO] VirtualBox detected. Configuring network interfaces...${RESET}"

  # Already configured? (either our drop-in, or a legacy in-file edit)
  if [ -f "$NETWORK_DROPIN" ] || grep -Fqs "auto eth1" /etc/network/interfaces; then
    echo -e "${YELLOW}[WARN] Network configuration for VirtualBox already exists. Skipping...${RESET}"
    return 0
  fi

  echo -e "${CYAN}[INFO] Writing VirtualBox interface config to $NETWORK_DROPIN...${RESET}"
  mkdir -p /etc/network/interfaces.d

  # Make sure the main file actually sources the drop-in directory (Kali's
  # default does, but a customized box might not).
  if ! grep -Fqs "source /etc/network/interfaces.d/*" /etc/network/interfaces; then
    echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces
  fi

  cat > "$NETWORK_DROPIN" <<EOF
# Added by kali_setup_any.sh for VirtualBox NAT-network setup.
# Primary network interface
auto eth0
iface eth0 inet dhcp

# Secondary network interface (NAT Network)
auto eth1
iface eth1 inet dhcp
EOF

  # ifupdown now owns eth0/eth1; if NetworkManager is also running it will treat
  # them as unmanaged. Warn so the hand-off is not a surprise.
  if systemctl is-active --quiet NetworkManager; then
    echo -e "${YELLOW}[WARN] NetworkManager is active - eth0/eth1 will be handled by ifupdown, not NM.${RESET}"
  fi

  systemctl restart networking.service
  echo -e "${GREEN}[SUCCESS] VirtualBox network configuration applied.${RESET}"
}

do_network_restore() {
  echo -e "${CYAN}[INFO] Restoring network configuration...${RESET}"
  if [ -f "$NETWORK_DROPIN" ]; then
    rm -f "$NETWORK_DROPIN"
    echo -e "${GREEN}[SUCCESS] Removed VirtualBox network drop-in.${RESET}"
    systemctl restart networking.service
  elif [ -f "$BACKUP_DIR/network_interfaces.bak" ]; then
    # Backwards compatibility: undo an old-style full-file backup from a run
    # made before the drop-in approach existed.
    cp "$BACKUP_DIR/network_interfaces.bak" /etc/network/interfaces
    echo -e "${GREEN}[SUCCESS] Restored network configuration from legacy backup.${RESET}"
    systemctl restart networking.service
  else
    echo -e "${RED}[ERROR] No VirtualBox drop-in or legacy backup found. Nothing to restore.${RESET}"
  fi
}

###############################################################################
# 11. Zsh Configuration + Restore
###############################################################################

do_zsh() {
  echo -e "${CYAN}[INFO] Configuring Zsh...${RESET}"

  # Auto-pick the newest dated history / zshrc in the repo so dropping a fresh
  # snapshot in needs no code edit (-t = sort by mtime, newest first).
  local ZSH_HISTORY_SOURCE ZSHRC_SOURCE
  ZSH_HISTORY_SOURCE=$(ls -t "$SOLVED_BOXES_DEST"/final_combined_history_*.txt 2>/dev/null | head -n1)
  ZSHRC_SOURCE=$(ls -t "$SOLVED_BOXES_DEST"/latest_zshrc_* 2>/dev/null | head -n1)
  local ZSH_HISTORY_DEST="/home/$CURRENT_USER/.zsh_history"
  local ZSHRC_DEST="/home/$CURRENT_USER/.zshrc"

  [ -n "$ZSH_HISTORY_SOURCE" ] && echo -e "${CYAN}[INFO] Using history snapshot: $(basename "$ZSH_HISTORY_SOURCE")${RESET}"
  [ -n "$ZSHRC_SOURCE" ]       && echo -e "${CYAN}[INFO] Using zshrc snapshot:   $(basename "$ZSHRC_SOURCE")${RESET}"

  mkdir -p "$BACKUP_DIR"

  if [ -f "$ZSHRC_DEST" ]; then
    echo -e "${CYAN}[INFO] Backing up existing .zshrc...${RESET}"
    cp "$ZSHRC_DEST" "$BACKUP_DIR/zshrc.bak"
  fi

  if [ -f "$ZSH_HISTORY_SOURCE" ]; then
    echo -e "${CYAN}[INFO] Merging Zsh history...${RESET}"
    cat "$ZSH_HISTORY_SOURCE" >> "$ZSH_HISTORY_DEST"
    sort -u "$ZSH_HISTORY_DEST" -o "$ZSH_HISTORY_DEST"
    # Files touched as root must end up owned by the user, or zsh ignores them.
    chown "$CURRENT_USER":"$CURRENT_USER" "$ZSH_HISTORY_DEST"
  fi

  if [ -f "$ZSHRC_SOURCE" ]; then
    echo -e "${CYAN}[INFO] Updating .zshrc...${RESET}"
    cp "$ZSHRC_SOURCE" "$ZSHRC_DEST"
    chown "$CURRENT_USER":"$CURRENT_USER" "$ZSHRC_DEST"
    # Sourcing in a throwaway subshell would not affect the user's shell, so
    # just tell them how to load it.
    echo -e "${YELLOW}[INFO] Open a new terminal or run 'exec zsh' to load the updated .zshrc.${RESET}"
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

# Track the outcome of each stage so the run ends with a clear at-a-glance
# summary instead of just scrolling apt output.
declare -a SUMMARY=()

run_stage() {
  # run_stage <label> <function-name>
  local label="$1" fn="$2"
  if "$fn"; then
    SUMMARY+=("${GREEN}[ OK ]${RESET}  $label")
  else
    SUMMARY+=("${YELLOW}[WARN]${RESET}  $label (reported errors)")
  fi
}

[ "$REPOS" = true ]           && run_stage "repos"            do_repos
[ "$PMPK" = true ]            && run_stage "pimpmykali"       do_pmpk
[ "$TOOLS" = true ]           && run_stage "tools"            do_tools
[ "$NETWORK" = true ]         && run_stage "network"          do_network
[ "$NETWORK_RESTORE" = true ] && run_stage "network-restore"  do_network_restore
[ "$ZSH_UPDATE" = true ]      && run_stage "zsh"              do_zsh
[ "$ZSH_RESTORE" = true ]     && run_stage "zsh-restore"      do_zsh_restore

echo
echo -e "${CYAN}=================== Run Summary ===================${RESET}"
if [ "${#SUMMARY[@]}" -eq 0 ]; then
  echo -e "  No install/modify stages were selected."
else
  for line in "${SUMMARY[@]}"; do
    echo -e "  $line"
  done
fi
echo -e "${CYAN}==================================================${RESET}"
echo -e "${GREEN}[SUCCESS] Script execution completed.${RESET}"
