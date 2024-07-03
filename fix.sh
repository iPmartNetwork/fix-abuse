#!/bin/bash

# Color codes
Purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color 

cur_dir=$(pwd)
# check root
#[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${Purple}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${Purple}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}


loader(){

    install_jq

    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    # Fetch server country using ip-api.com
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

    # Fetch server isp using ip-api.com 
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

    init

}

init(){

    #clear page .
    clear

    # Function to display ASCII logo
    echo -e "${Purple}"
    cat << "EOF"

══════════════════════════════════════════════════════════════════════════════════════
        ____                             _     _                                     
    ,   /    )                           /|   /                                  /   
-------/____/---_--_----__---)__--_/_---/-| -/-----__--_/_-----------__---)__---/-__-
  /   /        / /  ) /   ) /   ) /    /  | /    /___) /   | /| /  /   ) /   ) /(    
_/___/________/_/__/_(___(_/_____(_ __/___|/____(___ _(_ __|/_|/__(___/_/_____/___\__

══════════════════════════════════════════════════════════════════════════════════════
EOF
    echo -e "${NC}"

    echo -e "${cyan}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${cyan}Server IP:${NC} $SERVER_IP"
    echo -e "${cyan}Server ISP:${NC} $SERVER_ISP"
    echo "══════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${YELLOW}Please choose an option:${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${cyan}| 1  - Abuse Fixer"
    echo -e "${White}| 2  - Status "
    echo -e "${cyan}| 3  - Unistall"
    echo -e "${White}| 0  - Exit"
    echo "══════════════════════════════════════════════════════════════════════════════════════"
    echo -e "\033[0m"

    read -p "Enter option number: " choice
    case $choice in
    1)
        install_fixer
        ;;
    2)
        echo "simple 2"
        ;;
    0)
        echo -e "${YELLOW}Exit...${NC}"
        exit 0
        ;;
    *)
        echo "Not valid"
        ;;
    esac
        

}

install_fixer(){

    read -p "Enter Config port  ( example : 2098,2087,2020... ): " ports
    read -p "Enter SSH port     ( example : 22 ): " ssh_port

    ufw enable

    ufw allow ${ssh_port}


}

loader
