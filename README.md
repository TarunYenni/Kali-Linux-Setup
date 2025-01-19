# **Kali Setup Script**

A robust and customizable Bash script to streamline the setup and configuration of Kali Linux. This script automates the installation of essential tools, network configuration, repository management, and environment customization, enhancing your penetration testing workflow.

---

## **Features**

- **Automated Setup:**
  - Installs essential tools for penetration testing and red teaming.
  - Configures network interfaces for VirtualBox environments.
  - Clones private repositories and updates existing ones.

- **Enhanced Usability:**
  - Color-coded output for clear user feedback (errors, warnings, success).
  - Informative progress messages throughout the execution.

- **Customizable Configuration:**
  - Merge custom Zsh history and `.zshrc` for a personalized terminal experience.
  - Restore backed-up configurations for network and Zsh.

- **Modular Execution:**
  - Run specific tasks using command-line options.
  - Execute the full setup with a single `--all` flag.

---

## **Usage**
```bash
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
```

### **Prerequisites**
- Kali Linux with `sudo` privileges.
- Internet connection to install packages and clone repositories.

### **Command Options**
Run the script with the following options:

| **Option**            | **Description**                                                                 |
|------------------------|---------------------------------------------------------------------------------|
| `--pmpk`              | Run only the PimpmyKali setup (N -> Y).                                         |
| `--repos`             | Clone both private repositories (`Solved_Boxes_Data` and `My_Pentest_Kit`).     |
| `--tools`             | Install additional penetration testing tools.                                  |
| `--network`           | Configure the network for VirtualBox environments.                             |
| `--zsh`               | Merge Zsh history and update `.zshrc` (requires `Solved_Boxes_Data`).           |
| `--network-restore`   | Restore `/etc/network/interfaces` from a previous backup.                      |
| `--zsh-restore`       | Restore the original `.zshrc` from a backup.                                   |
| `--all`               | Run all tasks sequentially (PimpmyKali, repos, tools, network, and Zsh).       |
| `-h`, `--help`        | Show the help message and usage examples.                                      |

### **Examples**
1. Run the full setup:
   ```bash
   sudo ./kali_setup.sh --all
