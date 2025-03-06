#!/bin/bash

# Exit on error
set -e

# Function to log messages with color and detailed information
log() {
    local COLOR_RESET='\033[0m'
    local COLOR_RED='\033[0;31m'
    local COLOR_GREEN='\033[0;32m'
    local COLOR_YELLOW='\033[0;33m'
    local COLOR_BLUE='\033[0;34m'
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    local LOG_LEVEL=$1
    local MESSAGE=$2

    case $LOG_LEVEL in
        ERROR)
            echo -e "${COLOR_RED}[${TIMESTAMP}] [ERROR] ${MESSAGE}${COLOR_RESET}"
            ;;
        SUCCESS)
            echo -e "${COLOR_GREEN}[${TIMESTAMP}] [SUCCESS] ${MESSAGE}${COLOR_RESET}"
            ;;
        INFO)
            echo -e "${COLOR_BLUE}[${TIMESTAMP}] [INFO] ${MESSAGE}${COLOR_RESET}"
            ;;
        WARNING)
            echo -e "${COLOR_YELLOW}[${TIMESTAMP}] [WARNING] ${MESSAGE}${COLOR_RESET}"
            ;;
        *)
            echo -e "[${TIMESTAMP}] [UNKNOWN] ${MESSAGE}${COLOR_RESET}"
            ;;
    esac
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up temporary files..."
    rm -f /tmp/ipv4.txt
    log "SUCCESS" "Cleanup completed."
}
trap cleanup EXIT

# Function to check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "This script must be run as root or with sudo privileges."
        exit 1
    else
        log "INFO" "Root privileges confirmed."
    fi
}

# Check and install dependencies
install_dependencies() {
    log "INFO" "Checking and installing required dependencies..."

    # Update package list
    if ! apt-get update > /dev/null 2>&1; then
        log "ERROR" "Failed to update package list. Please check your internet connection."
        exit 1
    fi

    # Install ipset
    if ! command -v ipset >/dev/null 2>&1; then
        log "INFO" "ipset is not installed. Installing it now..."
        if ! apt-get install -y ipset > /dev/null 2>&1; then
            log "ERROR" "Failed to install ipset. Please install it manually."
            exit 1
        fi
        log "SUCCESS" "ipset installed successfully."
    else
        log "INFO" "ipset is already installed."
    fi

    # Install curl
    if ! command -v curl >/dev/null 2>&1; then
        log "INFO" "curl is not installed. Installing it now..."
        if ! apt-get install -y curl > /dev/null 2>&1; then
            log "ERROR" "Failed to install curl. Please install it manually."
            exit 1
        fi
        log "SUCCESS" "curl installed successfully."
    else
        log "INFO" "curl is already installed."
    fi
}

# Fetch IP ranges
fetch_ip_ranges() {
    log "INFO" "Fetching IP ranges from remote server..."
    if ! curl -s --retry 3 --retry-delay 5 'https://raw.githubusercontent.com/ipmartnetwork/fix-abuse/main/ipv4.txt' -o /tmp/ipv4.txt; then
        log "ERROR" "Failed to fetch the IP list from remote server."
        log "ERROR" "Please check your internet connection and try again."
        exit 1
    fi
}

# Block IP ranges using ipset
block_ip_ranges() {
    log "INFO" "Starting IP range blocking procedure..."

    # Create ipset
    if ! ipset list AS_Blocker >/dev/null 2>&1; then
        ipset create AS_Blocker hash:net
        log "INFO" "Created new ipset for blocked ranges (AS_Blocker)."
    else
        ipset flush AS_Blocker
        log "INFO" "Flushed existing ipset for blocked ranges (AS_Blocker)."
    fi

    # Add IP ranges to ipset
    log "INFO" "Adding IP ranges to ipset (AS_Blocker)..."
    while IFS= read -r range; do
        if [[ -n "$range" && ! "$range" =~ ^[[:space:]]*# && "$range" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            ipset add AS_Blocker "$range"
            log "INFO" "Blocked range: $range"
        fi
    done < /tmp/Ips.txt

    # Add iptables rule
    if ! iptables -C OUTPUT -m set --match-set AS_Blocker dst -j DROP >/dev/null 2>&1; then
        iptables -I OUTPUT -m set --match-set AS_Blocker dst -j DROP
        log "INFO" "Added iptables rule for blocked ranges (AS_Blocker)."
    fi

    # Ensure /etc/iptables directory exists
    if [ ! -d /etc/iptables ]; then
        log "INFO" "/etc/iptables directory does not exist. Creating it now..."
        mkdir -p /etc/iptables
        chmod 755 /etc/iptables
    fi

    # Ensure rules.v4 file exists
    if [ ! -f /etc/iptables/rules.v4 ]; then
        log "INFO" "/etc/iptables/rules.v4 does not exist. Creating it now..."
        touch /etc/iptables/rules.v4
        chmod 644 /etc/iptables/rules.v4
    fi

    # Save rules
    ipset save > /etc/ipset.conf
    iptables-save > /etc/iptables/rules.v4
    log "SUCCESS" "All IP ranges have been successfully blocked."

    # Show success message and wait for user input
    clear
    echo -e "\033[0;32m=== SUCCESS ===\033[0m"
    echo -e "\033[0;32mAll IP ranges have been successfully blocked.\033[0m"
    echo -e "\033[0;32mPress Enter to return to the main menu...\033[0m"
    read -p ""
}

# Setup automatic updates
setup_auto_updates() {
    log "INFO" "Setting up automatic updates..."

    # Ensure /etc/iPmartNetwork/fix-abuse directory exists
    if [ ! -d /etc/iPmartNetwork/fix-abuse-v2 ]; then
        log "INFO" "/etc/iPmartNetwork/fix-abuse-v2 directory does not exist. Creating it now..."
        mkdir -p /etc/iPmartNetwork/fix-abuse-v2
        chmod 755 /etc/iPmartNetwork/fix-abuse-v2
    fi

    # Create fix-v2.sh script in the new directory
    if [ ! -f /etc/iPmartNetwork/fix-abuse-v2/fix-v2.sh ]; then
        cat > /etc/iPmartNetwork/fix-abuse-v2/fix-v2.sh <<'EOF'
#!/bin/bash
set -e
exec 1> >(logger -s -t $(basename \$0))
IP_LIST=\$(curl -s --retry 3 --retry-delay 5 'https://raw.githubusercontent.com/ipmartnetwork/fix-abuse/main/ipv4.txt')
if [ -n "\$IP_LIST" ]; then
while IFS= read -r RANGE; do
if [[ -n "\$RANGE" && ! "\$RANGE" =~ ^[[:space:]]*# && "\$RANGE" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
ipset add AS_Blocker "\$RANGE"
fi
done <<< "\$IP_LIST"
ipset save > /etc/ipset.conf
# Ensure /etc/iptables directory exists
if [ ! -d /etc/iptables ]; then
mkdir -p /etc/iptables
chmod 755 /etc/iptables
fi
# Ensure rules.v4 file exists
if [ ! -f /etc/iptables/rules.v4 ]; then
touch /etc/iptables/rules.v4
chmod 644 /etc/iptables/rules.v4
fi
iptables-save > /etc/iptables/rules.v4
fi
EOF
        chmod +x /etc/iPmartNetwork/fix-abuse-v2/fix-v2.sh
        log "SUCCESS" "Created and configured fix-v2.sh in /etc/iPmartNetwork/fix-abuse-v2/."
    else
        log "INFO" "fix-v2.sh already exists in /etc/iPmartNetwork/fix-abuse-v2/, skipping creation."
    fi

    # Setup cron job to run the script from the new directory every 10 minutes
    log "INFO" "Setting up cron job for automatic updates..."
    CRON_JOB="*/10 * * * * /etc/iPmartNetwork/fix-abuse-v2/fix-v2.sh >> /var/log/as-def.log 2>&1"
    if ! (crontab -l 2>/dev/null | grep -Fxq "$CRON_JOB"); then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "SUCCESS" "Auto-update configured to run every 10 minutes."
    else
        log "INFO" "Cron job already exists, skipping setup."
    fi

    # Show success message and wait for user input
    clear
    echo -e "\033[0;32m=== SUCCESS ===\033[0m"
    echo -e "\033[0;32mAutomatic updates have been successfully configured.\033[0m"
    echo -e "\033[0;32mThe fix-v2.sh script will run every 10 minutes via cron.\033[0m"
    echo -e "\033[0;32mPress Enter to return to the main menu...\033[0m"
    read -p ""
}

# Main menu function
show_menu() {
    local COLOR_RESET='\033[0m'
    local COLOR_BLUE='\033[0;34m'
    local COLOR_GREEN='\033[0;32m'
    local COLOR_RED='\033[0;31m'
    while true; do
        clear
        echo -e "${COLOR_BLUE}=== IP Blocking Management Tool ===${COLOR_RESET}"
        echo -e "${COLOR_BLUE}1.${COLOR_RESET} ${COLOR_GREEN}Block IP ranges now${COLOR_RESET}"
        echo -e "${COLOR_BLUE}2.${COLOR_RESET} ${COLOR_GREEN}Setup automatic updates${COLOR_RESET}"
        echo -e "${COLOR_BLUE}3.${COLOR_RESET} ${COLOR_GREEN}Exit${COLOR_RESET}"
        echo
        read -p "Please select an option (1-3): " choice

        case $choice in
            1)
                fetch_ip_ranges
                block_ip_ranges
                ;;
            2)
                setup_auto_updates
                ;;
            3)
                log "INFO" "Exiting..."
                exit 0
                ;;
            *)
                log "WARNING" "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Main execution
main() {
    check_root
    install_dependencies
    show_menu
}

# Start script
main
