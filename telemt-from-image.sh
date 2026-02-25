#!/bin/bash

# Distroless Image for Telemt - a fast Rust-based MTProxy (MTProto) server
# Usage:
# chmod +x ./telemt-from-image.sh
# ./telemt-from-image.sh

# --- docker images:     --------------------------------------------
# 1
# Distroless build of https://github.com/telemt/telemt by whn0thacked
IMAGE_NAME="whn0thacked/telemt-docker:latest" # https://github.com/An0nX/telemt-docker/blob/master/README.md

# 2
# Distroless build of https://github.com/telemt/telemt by whn0thacked (Copy)
# IMAGE_NAME="exalon/telemt-docker:latest"  # https://hub.docker.com/repository/docker/exalon/telemt-docker/general

# 3
# new Distroless build of https://github.com/telemt/telemt 
# IMAGE_NAME="exalon/telemt:latest"  # https://hub.docker.com/repository/docker/exalon/telemt/general
# --------------------------------------------------------------------

# --- Def Conf ---
PORT="4433"
SITE="google.com"

# --- Conf ---
OVERWRITE=true
CONFIG_FILE="telemt.toml"
COMPOSE_FILE="docker-compose.yml"
AD_TAG="000empty000"

BUILD_SCRIPT_URL="https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-build-from-source.sh"
SCRIPT_NAME=$(basename "$BUILD_SCRIPT_URL")        

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Functions ---

# Eye candy
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; } 
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

# Check for root privileges
[ "$EUID" -ne 0 ] && { echo -e "${RED}[ERROR] Please run as root ${NC}"; exit 1; }


# Check if container is running
is_running() { [ "$(docker inspect -f '{{.State.Running}}' telemt 2>/dev/null)" == "true" ]; }

# Get public IP address
get_public_ip() { curl -s --max-time 5 ifconfig.me || echo "YOUR_IP"; }

# Generate and display the MTProto proxy link
print_proxy_link() {
    local p=$1 s=$2
    local ip=$(get_public_ip)
    local domain_hex=$(echo -n "$SITE" | od -A n -t x1 | tr -d ' \n')
    local full_secret="ee${s}${domain_hex}"    
    local link="tg://proxy?server=$ip&port=$p&secret=$full_secret"
    echo "$link" > "proxy_link.txt"

    echo -e "=========================================================="
    echo -e "Copy the link below to Telegram and click it to activate the proxy"
    echo -e "🔗 ${CYAN}$link${NC}"
    echo -e "=========================================================="
}

# Pull image and (re)start the Docker container
deploy_container() {
    # Remove old resources
    info "Removing old containers..."
    docker compose down --remove-orphans >/dev/null 2>&1

    # Download image
    info "Pulling latest image..."
    docker compose pull && start_container || { err "Failed to deploy. Docker environment is not ready!"; exit 1; }
}
# Start container
start_container() {
    #info "Cleaning up network interfaces..."
    #docker network prune -f >/dev/null 2>&1

    # Start existing containers
    info "Starting container..."
    docker compose up -d || { err "Start failed!"; exit 1; }
#   docker compose up -d --force-recreate || { err "Start failed!"; exit 1; }
}

# Generate configuration files (telemt.toml and docker-compose.yml)
prepare_files() {
info "Cleaning up old configuration files..."
rm -f "$CONFIG_FILE" "$COMPOSE_FILE"
/*
    for file in "$CONFIG_FILE" "$COMPOSE_FILE"; do
        if [ -f "$file" ]; then
            if [ "$OVERWRITE" = false ]; then
                read -p "[?] $file exists. [ENTER] to confirm or type anything to cancel: " -r; echo
                [[ -n $REPLY ]] && { err "Cancelled."; exit 1; }
            fi
            rm "$file"
        fi
    done
*/
}

# Check and install Docker, Docker Compose, and dependencies
check_and_install() {
    #removed#
    #   0. Check for repeated run     #    [ -f ".setup_done" ] && return 0

    # 1. Ask for permission
    info "This script can check & install dependencies (Update, Docker, Compose, OpenSSL, lsof)"
    echo -ne "${YELLOW}[?] Press [ENTER] to check/install or ANY OTHER KEY to skip: ${NC}"
    read -n 1 -s REPLY
    echo "" # New line after key press

    #rem#
    # If NOT an empty string (i.e., not ENTER), skip installation
    if [[ -n $REPLY ]]; then
    info "Dependency check skipped by user"
      #  touch .setup_done
        return 0
    fi

    # 2. Update package lists
    echo -ne "[>] Updating package lists... "
    if apt-get update -y >/dev/null 2>&1; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC} (Check internet)"
    fi

    # 3. Docker
    echo -ne "[>] Checking Docker... "
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
        systemctl enable --now docker >/dev/null 2>&1
    fi

    # 4. Docker Compose
    echo -ne "[>] Checking Docker Compose... "
    if docker compose version >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        apt-get install -y docker-compose-plugin >/dev/null 2>&1
    fi

    # 5. OpenSSL
    echo -ne "[>] Checking OpenSSL... "
    if command -v openssl >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        apt-get install -y openssl >/dev/null 2>&1
    fi
    
    # 6. LSOF
    echo -ne "[>] Checking lsof... "
    if command -v lsof >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        apt-get install -y lsof >/dev/null 2>&1
    fi
    #   
    echo -e "\n${GREEN}[*] Environment is ready!${NC}"
    echo -ne "${YELLOW}[?] Press [ENTER] to continue...${NC}"
    read -r 
    # touch .setup_done
}

status_detection() {
    # 1. Check for the existence of the link file BEFORE checking Docker
    if [ -f "proxy_link.txt" ]; then
        local raw_link=$(head -n 1 proxy_link.txt)
        EXISTING_LINK="LINK:${GREEN}$raw_link${NC}"	
    else
        EXISTING_LINK="${YELLOW}⚠️ File proxy_link.txt not found (Install first)${NC}"
    fi

    # 2. Check if installation files exist
    if [ -f "$COMPOSE_FILE" ]&& command -v docker >/dev/null 2>&1; then
        INST_ICON="${GREEN}●${NC}"
        
        # 3. Check if the container is running
        if is_running; then
            ACT_ICON="${GREEN}●${NC}"
            STATUS_MSG="(Status: ${GREEN}Active${NC})"
            TOGGLE_ACTION="Turn OFF Proxy"
        else
            ACT_ICON="${RED}○${NC}"
            STATUS_MSG="(Status: ${YELLOW}Stopped${NC})"
            TOGGLE_ACTION="Turn ON Proxy "
            # If Docker is inactive, we DO NOT overwrite EXISTING_LINK;
            # we can simply add a note to the STATUS_MSG if needed.
        fi
    else
        INST_ICON="${RED}○${NC}"
        ACT_ICON="${RED}○${NC}"
        STATUS_MSG="${RED}(Not installed)${NC}"
        TOGGLE_ACTION="Not installed"
        EXISTING_LINK="" # In this case, the link is truly not needed
    fi
    DOCKER_INFO="\nSTATUS:  Installed [${INST_ICON}]  |  Active [${ACT_ICON}]"
}

gui_top() {
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║              MTProxy (Telemt) Installer            ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}Build from existing image: $IMAGE_NAME"
}

main_menu() {
    echo -e "$DOCKER_INFO"
    [ -n "$EXISTING_LINK" ] && echo -e "$EXISTING_LINK"
    echo -e "\n\nSelect action: "
    echo -e "${NC}\nBuild from existing image: $IMAGE_NAME"
    echo -e " 1) ${CYAN}Fast Install             (Port: $PORT, Domain: $SITE)${NC}"
    echo -e " 2) Custom Install           (Custom Port, Domain...)"
    echo -e " 3) ${YELLOW}${TOGGLE_ACTION} ${NC}          $STATUS_MSG"
    echo -e " 4) ${RED}Full Uninstall${NC}           (Stop & Remove All)\n"
    echo -e " 5) Run external build script: $SCRIPT_NAME)"
    echo -ne "\n${YELLOW}[?] Choose option [1-5]:${NC} "
    read -r INSTALL_MODE
}

# --- Output (start actions)---
clear
# check_and_install
status_detection
gui_top
main_menu

# Logic Selection
case $INSTALL_MODE in
    1) check_and_install && info "Mode: Fast Install\n" ;;
    2) check_and_install && info "Mode: Manual Install"; OVERWRITE=false ;;
    3)
        if [ -f "$COMPOSE_FILE" ]; then
            if is_running; then
                info "Stopping container..."
                docker compose stop && info "Stopped."
                exit 0 
            else
                start_container
                exit 0
            fi
        else
            err "Proxy is not installed yet"
        fi
        ;;
    4)
        warn "This will remove EVERYTHING related to Telemt"
        read -p "[?] Are you sure? [ENTER] to confirm or type anything to cancel: " -r; echo
        if [[ -z $REPLY ]]; then
            # 1. Remove rules from UFW (two lines: file check + actions)
            [ -f "$CONFIG_FILE" ] && { 
                OLD_PORT=$(grep "port =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d '[:space:]"')
                [ -n "$OLD_PORT" ] && command -v ufw >/dev/null && ufw delete allow "$OLD_PORT"/tcp || true; }
            # 2. Remove container and images (single line)
            [ -f "$COMPOSE_FILE" ] && { info "Cleaning Docker..."; docker compose down --rmi all --volumes --remove-orphans; }
            # 3. Clean files
            rm -f "$CONFIG_FILE" "$COMPOSE_FILE" "proxy_link.txt"
            info "Uninstall complete. System is clean."
        fi
        exit 0 ;;
    5)
        info "Fetching build script..."
        curl -sLO "$BUILD_SCRIPT_URL"
        if [ -f "./$SCRIPT_NAME" ]; then
            chmod +x "./$SCRIPT_NAME"
            exec "./$SCRIPT_NAME"
        else
            err "Failed to download script from GitHub."
            exit 1
        fi
        ;;
    *) err "Invalid option."; exit 1 ;;
esac


# --- Proxy Secret: Keep Existing or New---
if [ -f "$CONFIG_FILE" ]; then
    OLD_SECRET=$(grep "docker =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' "')
    echo -e "${YELLOW}[?] Config found. Use existing secret? ($OLD_SECRET)${NC}"
    echo -e "${CYAN}    (Keeping the old secret will keep your current proxy link working)${NC}"
    read -p "[?] [ENTER] to keep current, type anything for a NEW one: " -r
    if [[ -z $REPLY ]]; then
        SECRET=$OLD_SECRET
        info "Keeping existing secret."
    else
        SECRET=$(openssl rand -hex 16)
        info "New secret generated: $SECRET"
        warn "Note: Old proxy links will no longer work!"
    fi
else
    SECRET=$(openssl rand -hex 16)
    info "Generated secret: $SECRET"
fi

# --- Custom setup parameters ---
# - PORT: The TCP port the proxy listens on (verified via lsof)
# - SITE: TLS domain for traffic masking (cloaking)
# - AD_TAG: Promotion tag for @MTProxybot registration
if [ "$OVERWRITE" = false ]; then
    # Start a loop to ensure the selected port is actually available
    while true; do
    read -p "[?] Enter port (default $PORT): " input_port
        PORT=${input_port:-$PORT}
        if lsof -i :"$PORT" -sTCP:LISTEN -t >/dev/null ; then
            warn "Port $PORT is already occupied!"
            lsof -i :"$PORT" -sTCP:LISTEN
            echo -e "${YELLOW}Please choose a different port or stop the service above.${NC}"
        else
            info "Port $PORT is available."
            break
        fi
    done
        
    read -p "[?] Enter domain (default $SITE): " input_site
    SITE=${input_site:-$SITE}    
    # Display connection details for the user before Ad_tag prompt
    echo -e "\n${CYAN}- To set up an Ad Tag, provide the settings above to @MTProxybot - ${NC}"
    echo -e "IP:Port: ${GREEN}$(get_public_ip):$PORT${NC}"
    echo -e "Secret:  ${GREEN}$SECRET${NC}"
    echo -e "${CYAN}--------------------------------${NC}"
    read -p "[?] Enter Ad_tag (press ENTER to skip): " input_tag
    AD_TAG=${input_tag:-$AD_TAG}    
fi

if command -v ufw >/dev/null && ufw status | grep -q "active"; then
    info "Opening port $PORT..."
    ufw allow "$PORT"/tcp
fi



# --- File Generation ---
prepare_files
info "Config ready: docker-compose.yml, telemt.toml"

cat > "$CONFIG_FILE" <<EOF
show_link = ["docker"]
[general]
fast_mode = true
use_middle_proxy = true
[general.modes]
classic = false
secure = false
tls = true
[server]
port = $PORT
listen_addr_ipv4 = "0.0.0.0"
listen_addr_ipv6 = "::"
#metrics_port = 9090
#metrics_whitelist = ["0.0.0.0", "::1"]
[[server.listeners]]
ip = "0.0.0.0"
[timeouts]
client_handshake = 15
tg_connect = 10
client_keepalive = 60
client_ack = 300
[censorship]
tls_domain = "$SITE"
mask = true
[access.users]
docker = "$SECRET"
EOF

cat > "$COMPOSE_FILE" <<EOF
services:
  telemt:
    image: $IMAGE_NAME
    container_name: telemt
    restart: unless-stopped
    volumes:
      - ./$CONFIG_FILE:/etc/telemt.toml:ro
    ports:
      - "$PORT:$PORT/tcp"
#      - "127.0.0.1:9090:9090/tcp"
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    security_opt:
     - no-new-privileges:true
    tmpfs:
      - /run/telemt:rw,nosuid,nodev,noexec,mode=1777,size=1m
      - /tmp:rw,nosuid,nodev,noexec,size=16m
    deploy:
      resources:
        limits:
          memory: 128M
#    ulimits:
#      nofile:
#        soft: 65536
#        hard: 65536
EOF

# print_proxy_link "$PORT" "$SECRET"

#  Execution 
if [ "$OVERWRITE" = true ]; then
    deploy_container && { echo -e "\n🎉 Proxy is ready to use!"; }
else
    echo -ne "[?] 🚀 ${GREEN}Start now?${NC} [ENTER] to confirm: "
    read -r REPLY
    [[ -z "$REPLY" ]] && deploy_container
fi

is_running && print_proxy_link "$PORT" "$SECRET" || info "Status: Stopped. Use Option 3 later."

#mn#
