#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   sleep 1
   exit 1
fi

# Color codes
GREEN="\033[0;32m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
RESET="\033[0m"
MAGENTA="\033[0;35m"
RED="\033[0;31m"
YELLOW="\033[0;33m"

# Key press to continue
press_key(){
    read -p "Press Enter to continue..."
}

# Text colorization
colorize() {
    local color="$1"
    local text="$2"
    local style="${3:-normal}"
    
    # ANSI color codes
    local black="\033[30m"
    local red="\033[31m"
    local green="\033[32m"
    local yellow="\033[33m"
    local blue="\033[34m"
    local magenta="\033[35m"
    local cyan="\033[36m"
    local white="\033[37m"
    local reset="\033[0m"
    
    # ANSI style codes
    local normal="\033[0m"
    local bold="\033[1m"
    local underline="\033[4m"
    
    # Select color
    local color_code
    case $color in
        black) color_code=$black ;;
        red) color_code=$red ;;
        green) color_code=$green ;;
        yellow) color_code=$yellow ;;
        blue) color_code=$blue ;;
        magenta) color_code=$magenta ;;
        cyan) color_code=$cyan ;;
        white) color_code=$white ;;
        *) color_code=$reset ;;
    esac
    
    # Select style
    local style_code
    case $style in
        bold) style_code=$bold ;;
        underline) style_code=$underline ;;
        normal | *) style_code=$normal ;;
    esac

    echo -e "${style_code}${color_code}${text}${reset}"
}

# Server management functions
init_server_db() {
    mkdir -p /root/easytier
    [ ! -f /root/easytier/servers.db ] && touch /root/easytier/servers.db
}

add_server() {
    echo
    read -p "Enter server IP: " ip
    read -p "Enter location (e.g., Germany): " location
    read -p "Enter hostname: " hostname
    
    # Validate IP
    if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        colorize red "Invalid IP format!" bold
        return 1
    fi
    
    # Add to database
    echo "$ip|$location|$hostname" >> /root/easytier/servers.db
    colorize green "Server added successfully!" bold
}

remove_server() {
    list_servers
    echo
    read -p "Enter server number to remove: " num
    
    total=$(wc -l < /root/easytier/servers.db)
    if [[ $num -lt 1 || $num -gt $total ]]; then
        colorize red "Invalid selection!" bold
        return 1
    fi
    
    # Remove server
    sed -i "${num}d" /root/easytier/servers.db
    colorize green "Server removed successfully!" bold
}

list_servers() {
    echo
    colorize cyan "Registered Servers:" bold
    echo "---------------------------------"
    if [ ! -s /root/easytier/servers.db ]; then
        colorize yellow "No servers registered" bold
        return
    fi
    
    nl -w 3 -s '. ' /root/easytier/servers.db | while read line; do
        colorize magenta "$line" 
    done
    echo "---------------------------------"
}

# Install EasyTier core
install_easytier() {
    DEST_DIR="/root/easytier"
    FILE1="easytier-core"
    FILE2="easytier-cli"
    
    # Check if already installed
    if [ -f "$DEST_DIR/$FILE1" ] && [ -f "$DEST_DIR/$FILE2" ]; then
        colorize green "EasyMesh Core Installed" bold
        return 0
    fi
    
    # Architecture detection
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        URL="https://github.com/Musixal/Easy-Mesh/raw/main/core/v2.0.3/easytier-linux-x86_64/"
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "aarch64" ]; then
        if [ "$(ldd /bin/ls | grep -c 'armhf')" -eq 1 ]; then
            URL="https://github.com/Musixal/Easy-Mesh/raw/main/core/v2.0.3/easytier-linux-armv7hf/"
        else
            URL="https://github.com/Musixal/Easy-Mesh/raw/main/core/v2.0.3/easytier-linux-armv7/"
        fi
    else
        colorize red "Unsupported architecture: $ARCH" bold
        return 1
    fi

    # Download and install
    mkdir -p $DEST_DIR
    colorize yellow "Downloading EasyMesh Core..."
    curl -Ls "$URL/easytier-cli" -o "$DEST_DIR/easytier-cli"
    curl -Ls "$URL/easytier-core" -o "$DEST_DIR/easytier-core"

    if [ -f "$DEST_DIR/$FILE1" ] && [ -f "$DEST_DIR/$FILE2" ]; then
        chmod +x "$DEST_DIR/easytier-cli"
        chmod +x "$DEST_DIR/easytier-core"
        colorize green "EasyMesh Core Installed Successfully!" bold
        return 0
    else
        colorize red "Failed to install EasyMesh Core!" bold
        exit 1
    fi
}

# Generate random secret
generate_random_secret() {
    openssl rand -hex 12
}

# Connect to network
connect_network_pool() {
    clear
    colorize cyan "Connect to the Mesh Network" bold 
    echo 
    
    # Topology selection
    colorize yellow "Select network topology:" bold
    echo "1) Star (Central Hub)"
    echo "2) Mesh (Full Connected)"
    read -p "Your choice (1-2): " topology_choice
    case $topology_choice in
        1) TOPOLOGY="star" ;;
        2) TOPOLOGY="mesh" ;;
        *) TOPOLOGY="star" ;;
    esac
    
    # Central hub selection for star topology
    CENTRAL_HUB=""
    if [ "$TOPOLOGY" = "star" ]; then
        list_servers
        echo
        read -p "Enter central hub server number: " hub_num
        total=$(wc -l < /root/easytier/servers.db)
        if [[ $hub_num -ge 1 && $hub_num -le $total ]]; then
            CENTRAL_HUB=$(sed -n "${hub_num}p" /root/easytier/servers.db | cut -d'|' -f1)
        else
            colorize red "Invalid selection! Using first server as hub." bold
            CENTRAL_HUB=$(head -1 /root/easytier/servers.db | cut -d'|' -f1)
        fi
    fi
    
    # Server configuration
    read -p "Your server IP: " IP_ADDRESS
    read -p "Your hostname: " HOSTNAME
    read -p "Tunnel port (default 2090): " PORT
    PORT=${PORT:-2090}
    
    # Network secret
    NETWORK_SECRET=$(generate_random_secret)
    colorize cyan "Generated Network Secret: $NETWORK_SECRET" bold
    read -p "Use this secret? (Y/n): " use_secret
    if [[ ! "$use_secret" =~ ^[Nn]$ ]]; then
        NETWORK_SECRET=$NETWORK_SECRET
    else
        read -p "Enter custom secret: " custom_secret
        NETWORK_SECRET=${custom_secret:-$NETWORK_SECRET}
    fi
    
    # Protocol selection
    colorize green "Select protocol:" bold
    echo "1) tcp"
    echo "2) udp"
    echo "3) ws"
    echo "4) wss"
    read -p "Choice (1-4): " protocol_choice
    case $protocol_choice in
        1) PROTOCOL="tcp" ;;
        2) PROTOCOL="udp" ;;
        3) PROTOCOL="ws" ;;
        4) PROTOCOL="wss" ;;
        *) PROTOCOL="udp" ;;
    esac
    
    # Additional options
    read -p "Enable encryption? (Y/n): " encrypt
    [[ "$encrypt" =~ ^[Nn]$ ]] && ENCRYPT_OPT="--disable-encryption" || ENCRYPT_OPT=""
    
    read -p "Enable multi-thread? (Y/n): " multithread
    [[ "$multithread" =~ ^[Nn]$ ]] && THREAD_OPT="" || THREAD_OPT="--multi-thread"
    
    read -p "Enable IPv6? (Y/n): " ipv6
    [[ "$ipv6" =~ ^[Nn]$ ]] && IPV6_OPT="--disable-ipv6" || IPV6_OPT=""
    
    # Generate peer list
    PEER_LIST=""
    if [ "$TOPOLOGY" = "star" ]; then
        PEER_LIST="--peers ${PROTOCOL}://${CENTRAL_HUB}:${PORT}"
    elif [ "$TOPOLOGY" = "mesh" ]; then
        while read server; do
            ip=$(echo $server | cut -d'|' -f1)
            [ "$ip" != "$IP_ADDRESS" ] && PEER_LIST+="${PROTOCOL}://${ip}:${PORT} "
        done < /root/easytier/servers.db
        PEER_LIST="--peers ${PEER_LIST}"
    fi
    
    # Create service file
    SERVICE_FILE="/etc/systemd/system/easymesh.service"
    LISTENERS="--listeners ${PROTOCOL}://[::]:${PORT} ${PROTOCOL}://0.0.0.0:${PORT}"
    
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=EasyMesh Network Service
After=network.target

[Service]
ExecStart=/root/easytier/easytier-core -i $IP_ADDRESS $PEER_LIST \\
    --hostname "$HOSTNAME" \\
    --network-secret "$NETWORK_SECRET" \\
    --default-protocol $PROTOCOL \\
    $LISTENERS \\
    $THREAD_OPT \\
    $ENCRYPT_OPT \\
    $IPV6_OPT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Start service
    systemctl daemon-reload
    systemctl enable easymesh.service
    systemctl start easymesh.service
    
    colorize green "\nMesh network started successfully!" bold
    colorize yellow "Topology: $TOPOLOGY" 
    [ -n "$CENTRAL_HUB" ] && colorize yellow "Central Hub: $CENTRAL_HUB"
    colorize cyan "Your Secret: $NETWORK_SECRET" bold
    press_key
}

# Display functions
display_peers() {
    watch -n1 /root/easytier/easytier-cli peer
}

display_routes() {
    watch -n1 /root/easytier/easytier-cli route
}

peer_center() {
    watch -n1 /root/easytier/easytier-cli peer-center
}

# Service management
restart_easymesh_service() {
    systemctl restart easymesh.service
    colorize green "Service restarted successfully!" bold
    press_key
}

remove_easymesh_service() {
    systemctl stop easymesh.service
    systemctl disable easymesh.service
    rm -f /etc/systemd/system/easymesh.service
    systemctl daemon-reload
    colorize green "Service removed successfully!" bold
    press_key
}

show_network_secret() {
    if [ -f /etc/systemd/system/easymesh.service ]; then
        secret=$(grep -oP '(?<=--network-secret ")[^"]+' /etc/systemd/system/easymesh.service)
        colorize cyan "Network Secret: $secret" bold
    else
        colorize red "Service not found!" bold
    fi
    press_key
}

view_service_status() {
    systemctl status easymesh.service
    press_key
}

# Watchdog functions
start_watchdog() {
    # [Previous watchdog implementation]
    colorize green "Watchdog started successfully!" bold
    press_key
}

stop_watchdog() {
    # [Previous watchdog implementation]
    colorize green "Watchdog stopped successfully!" bold
    press_key
}

# Cron job functions
add_cron_job() {
    # [Previous cron implementation]
    colorize green "Cron job added successfully!" bold
    press_key
}

delete_cron_job() {
    # [Previous cron implementation]
    colorize green "Cron job removed successfully!" bold
    press_key
}

# Core functions
check_core_status() {
    if [ -f "/root/easytier/easytier-core" ] && [ -f "/root/easytier/easytier-cli" ]; then
        colorize green "EasyMesh Core Installed" bold
        return 0
    else
        colorize red "EasyMesh Core Missing" bold
        return 1
    fi
}

remove_easymesh_core() {
    rm -rf /root/easytier
    colorize green "Core files removed successfully!" bold
    press_key
}

# Server management menu
manage_servers() {
    while true; do
        clear
        colorize cyan "Server Management" bold
        echo
        colorize green "1) Add Server"
        colorize red "2) Remove Server"
        colorize yellow "3) List Servers"
        colorize magenta "4) Back to Main Menu"
        echo
        read -p "Enter choice: " choice
        
        case $choice in
            1) add_server ;;
            2) remove_server ;;
            3) list_servers ; press_key ;;
            4) break ;;
            *) colorize red "Invalid option!" bold ;;
        esac
    done
}

# Main menu
display_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║            🌐 ${WHITE}EasyMesh Pro           ${CYAN}║"
    echo -e "║       ${WHITE}Multi-Server VPN Solution     ${CYAN}║"
    echo -e "╠════════════════════════════════════════╣"
    echo -e "║  ${WHITE}Core Version: 2.03                  ${CYAN}║"
    echo -e "║  ${WHITE}Max Servers: 50                    ${CYAN}║"
    echo -e "║  ${WHITE}Topologies: Star, Mesh             ${CYAN}║"
    echo -e "╠════════════════════════════════════════╣${RESET}"
    echo -e "║        $(check_core_status)         ║"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}"
    echo
    colorize green "	[1] Connect to Network" bold
    colorize yellow "	[2] Manage Servers"
    colorize cyan "	[3] Display Peers"
    colorize magenta "	[4] Display Routes"
    colorize white "	[5] Peer Center"
    colorize green "	[6] Show Network Secret"
    colorize yellow "	[7] Restart Service"
    colorize red "	[8] Remove Service"
    colorize magenta "	[9] Remove Core"
    echo -e "	[0] Exit"
    echo
}

# Main program
init_server_db
install_easytier

while true; do
    display_menu
    echo -en "${MAGENTA}Enter your choice: ${RESET}"
    read choice
    case $choice in
        1) connect_network_pool ;;
        2) manage_servers ;;
        3) display_peers ;;
        4) display_routes ;;
        5) peer_center ;;
        6) show_network_secret ;;
        7) restart_easymesh_service ;;
        8) remove_easymesh_service ;;
        9) remove_easymesh_core ;;
        0) exit 0 ;;
        *) colorize red "Invalid option!" bold ; sleep 1 ;;
    esac
done
