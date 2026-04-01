#!/bin/bash

# Install Telemt proxy server (MTProxy) via Docker Distroless
# telemt-from-image-mu.sh
# Changelog: ip4, random url, ask +,  #9), #ad_tag, multi user

# Check for root privileges
[ "$EUID" -ne 0 ] && { echo -e "${RED}[ERROR] Please run as root ${NC}"; exit 1; }

# --- Docker images:     --------------------------------------------
# 1 # Build https://github.com/telemt/telemt by whn0thacked = latest
IMAGE_NAME="whn0thacked/telemt-docker:latest" # https://github.com/An0nX/telemt-docker/blob/master/README.md

# 2 # Build https://github.com/telemt/telemt by whn0thacked = Copy at 2026-02
# IMAGE_NAME="exalon/telemt-docker:latest"  # https://hub.docker.com/repository/docker/exalon/telemt-docker/general


# --- Def Conf ---
PORT="4433"
# SITE="google.com"
# Fetch random site or default to google.com
SITE=$(curl -s https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/site.txt | shuf -n 1)
SITE=${SITE:-"google.com"}

# --- Default values ---
OVERWRITE=true
CONFIG_FILE="telemt.toml"
COMPOSE_FILE="docker-compose.yml"
PROXY_LINK_FILE="proxy_link.txt" # 
AD_TAG="000empty000"
BUILD_SCRIPT_URL="https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-source.sh"; SCRIPT_NAME=$(basename "$BUILD_SCRIPT_URL")        
MAX_USERS=16

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
ask()   { echo -ne "${YELLOW}[?]${NC} $*"; }

# Check if container is running
is_running() { [ "$(docker inspect -f '{{.State.Running}}' telemt 2>/dev/null)" == "true" ]; }
# Get public IP address
get_public_ip() { curl -4 -s --max-time 5 ifconfig.me || echo "YOUR_IP"; }
# Generate and display the MTProto proxy link
print_proxy_link() {
    local p=$1 s=$2 ip=$(get_public_ip)
    local domain_hex=$(echo -n "$SITE" | od -A n -t x1 | tr -d ' \n')
    local prefix="" suffix="" # local link="tg://proxy?server=$ip&port=$p&secret=ee${s}${domain_hex}"

    # Select prefix and suffix based on active mode
    [ "$PROTO_TLS" = "true" ] && { prefix="ee"; suffix="$domain_hex"; }
    [ "$PROTO_SECURE" = "true" ] && prefix="dd"

    local link="tg://proxy?server=$ip&port=$p&secret=${prefix}${s}${suffix}"
    echo "Default: $link" > "$PROXY_LINK_FILE"   

    echo -e "=========================================================="
    echo -e "Copy the link below to Telegram and click it to activate the proxy"
    echo -e "🔗 Default link: ${CYAN}$link${NC}"
    # echo -e "=========================================================="  
    
    # test
    # 1. TLS Mode: Uses "ee" prefix + secret + hex domain.
    # local link_tls="tg://proxy?server=$ip&port=$p&secret=ee${s}${domain_hex}"; info "[TLS Mode]: $link_tls"
    # 2. Secure Mode: Uses "dd" prefix + secret.
    # local link_secure="tg://proxy?server=$ip&port=$p&secret=dd${s}"; info "[Secure Mode]: $link_secure"
    # 3. Classic Mode: Raw 32-char secret without any prefixes.
    # local link_classic="tg://proxy?server=$ip&port=$p&secret=${s}"; info "[Classic Mode]: $link_classic"

    # Extract additional users from the configuration file    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Locate the [access.users] section and process all lines containing '='
        local users_list=$(sed -n '/\[access.users\]/,$p' "$CONFIG_FILE" | grep "=" | grep -v "docker =")
        
        if [[ -n "$users_list" ]]; then
            echo -e "🔗 Additional user list: "
            echo "$users_list" | while read -r line; do
                # Extract username (before '=') and secret (inside quotes)
                local u_name=$(echo "$line" | cut -d'=' -f1 | tr -d ' ')
                local u_secret=$(echo "$line" | cut -d'"' -f2)
                # Construct the Telegram proxy link
                local u_link="tg://proxy?server=$ip&port=$p&secret=ee${u_secret}${domain_hex}"
                # Output the link to the console and save it to the file
                echo -e "$u_name 🔗 ${CYAN}$u_link${NC}"
                echo "$u_name: $u_link" >> "$PROXY_LINK_FILE"
            done
        else
            echo -e "(There are no additional users)"
        fi
    fi
    
    echo -e "=========================================================="
    info "All links saved to $PROXY_LINK_FILE"
    info "Metrics available at: $ip:9090/metrics"
}

# Pull image and (re)start the Docker container
deploy_container() {
    # Remove old resources
    info "Removing old containers..."
    docker compose down --remove-orphans >/dev/null 2>&1
    # Download image
    info "Pulling latest image..."
    docker compose pull && start_container || { err "Failed to deploy. Docker environment is not ready!"; exit 1; }
    echo ""
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
echo; info "Cleaning up old configuration files..."
rm -f "$CONFIG_FILE" "$COMPOSE_FILE"
}

# Check and install Docker, Docker Compose, and dependencies
check_and_install() {
    #removed#
    #   0. Check for repeated run     #    [ -f ".setup_done" ] && return 0

    # 1. Ask for permission
    info "This script can check & install dependencies (Update, Docker, Compose, OpenSSL, lsof)"
    #echo -ne "${YELLOW}[?] Press [ENTER] to check/install or ANY OTHER KEY to skip: ${NC}"
    ask "Press [ENTER] to check/install or ANY OTHER KEY to skip: "
    IFS= read -n 1 -s REPLY
    echo "" 

    if [[ -n "$REPLY" ]]; then
        info "Dependency check skipped by user"
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
        if curl -fsSL https://get.docker.com | sh >/dev/null 2>&1; then
            systemctl enable --now docker >/dev/null 2>&1
        else
            err "Failed to install Docker."
            exit 1 # Прерываем, если Docker не поставился
        fi
    fi
    # 4. Docker Compose
    echo -ne "[>] Checking Docker Compose... "
    if docker compose version >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        if apt-get install -y docker-compose-plugin >/dev/null 2>&1; then
            echo -e "${GREEN}Done${NC}"
        else
            err "Failed to install Docker Compose plugin."
            exit 1
        fi
    fi

    # 5. OpenSSL
    echo -ne "[>] Checking OpenSSL... "
    if command -v openssl >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        if apt-get install -y openssl >/dev/null 2>&1; then
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${RED}Failed${NC}"
            err "Could not install OpenSSL. Check your package manager."
            exit 1
        fi
    fi

    # 6. LSOF
    echo -ne "[>] Checking lsof... "
    if command -v lsof >/dev/null 2>&1; then
        echo -e "${GREEN}Found${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        if apt-get install -y lsof >/dev/null 2>&1; then
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${RED}Failed${NC}"
            err "Could not install lsof."
            exit 1 # Выход из скрипта при ошибке
        fi
    fi
    # echo -e "\n${GREEN}[*] Environment is ready!${NC}"
    info "Environment is ready!\n"    
    # echo -ne "${YELLOW}[?] Press [ENTER] to continue...${NC}"
    ask "Press [ENTER] to continue... "; read -r 
    # touch .setup_done
}

status_detection() {
    # 1. Check for the existence of the link file BEFORE checking Docker
    if [ -f "$PROXY_LINK_FILE" ]; then
        local raw_link=$(head -n 1 "$PROXY_LINK_FILE" | sed 's/.*tg:\/\//tg:\/\//')
        #EXISTING_LINK="LINK:${GREEN}$raw_link${NC}"
        EXISTING_LINK="LINK: ${GREEN}$raw_link${NC}\n additional user links (if they exist) are in $PROXY_LINK_FILE"
    else
        #EXISTING_LINK="${YELLOW}⚠️ File proxy_link.txt not found (Install first)${NC}"
        EXISTING_LINK="${YELLOW}⚠️ File $PROXY_LINK_FILE not found (Install first)${NC}"
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
            TOGGLE_ACTION="Turn ON  Proxy"
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
echo -e "${NC}Build from image: $IMAGE_NAME"
}

main_menu() {
    echo -e "$DOCKER_INFO"
    [ -n "$EXISTING_LINK" ] && echo -e "$EXISTING_LINK"
    echo -e "\n\nSelect action:\n"
    echo -e " 1) ${CYAN}Fast Install             (Port: $PORT, Domain: $SITE)${NC}"
    echo -e " 2) Custom Install           (Custom Port, Domain...)"    
    echo -e " 3) ${YELLOW}${TOGGLE_ACTION} ${NC}          $STATUS_MSG"
    echo -e " 4) ${RED}Full Uninstall${NC}           (Stop & Remove All)\n"
    echo -e " 5) ${GREEN}Update Image${NC}             (Pull latest & Restart)"
    # echo -e " 9) Run external build script: $SCRIPT_NAME"
    # echo -ne "\n${YELLOW}[?] Choose option [1-5]:${NC} "
    echo -e ""; ask "Choose option [1-5]: "
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
                info "Stopping container..."; docker compose stop && info "Stopped."
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
        warn "This will remove EVERYTHING related to Telemt (rm telemt.toml, docker-compose.yml, proxy_link.txt)"
        read -p "[?] Are you sure? Press [ENTER] to confirm or type anything to cancel: " -r        
        if [[ -z "$REPLY" ]]; then
            # 1. Remove rules from UFW (two lines: file check + actions)
            [ -f "$CONFIG_FILE" ] && { 
                OLD_PORT=$(grep "port =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d '[:space:]"')
                [ -n "$OLD_PORT" ] && command -v ufw >/dev/null && ufw delete allow "$OLD_PORT"/tcp || true; }
            # 2. Remove container and images (single line)
            [ -f "$COMPOSE_FILE" ] && { info "Cleaning Docker..."; docker compose down --rmi all --volumes --remove-orphans; }
            # 3. Clean files
            rm -f "$CONFIG_FILE" "$COMPOSE_FILE" "$PROXY_LINK_FILE"
            info "Uninstall complete. System is clean."
        fi
        exit 0 ;;
     5)
        info "Updating Telemt image..."
        if [ -f "$COMPOSE_FILE" ]; then
            docker compose pull && docker compose up -d --remove-orphans
            info "Update complete. Running latest version."
        else
            err "Configuration not found. Install proxy first."
        fi
        exit 0 ;;
    9)
        info "Fetching build script..."
        curl -sLO "$BUILD_SCRIPT_URL" || { err "Failed to download script."; exit 1; }
        chmod +x "./$SCRIPT_NAME" && exec "./$SCRIPT_NAME"
        ;;
    *) err "Invalid option."; exit 1 ;;
esac

# --- Protocol Mode Selection (Custom Install) ---
PROTO_CLASSIC="false"; PROTO_SECURE="false" ; PROTO_TLS="false"
if [ "$OVERWRITE" = false ]; then
    echo ""
    echo -e "${CYAN}Select proxy protocol mode:${NC}"
    echo -e " 1) ${GREEN}TLS Mode${NC}       (tls = true, secure = false, classic = false)"
    echo -e " 2) ${GREEN}Secure Mode${NC}    (tls = false, secure = true, classic = false)"
    echo -e " 3) ${YELLOW}Classic Mode${NC}   (tls = false, secure = false, classic = true)"
    ask "Choose mode (default - TLS): "
    read -r proto_choice
        
    case "$proto_choice" in
        2) PROTO_SECURE="true"; info "Selected: Secure Mode" ;;
        3) PROTO_CLASSIC="true"; info "Selected: Classic Mode" ;;
        1|*) PROTO_TLS="true"; info "Selected: TLS Mode (default)" ;;
    esac
else
    PROTO_TLS="true"; info "Selected: TLS Mode"
fi


# --- Proxy Secret: Keep Existing or New ---
if [ -f "$CONFIG_FILE" ]; then
    # 1. Finds only the line starting with "docker", takes the first match, and cleans it
    OLD_SECRET=$(grep "^docker =" "$CONFIG_FILE" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')
    echo -e "${YELLOW}[?] Config found. Use existing secrets? ($OLD_SECRET and others)${NC}"
    echo -e "${CYAN}    (This will restore ALL users from the previous config)${NC}"
    
    # Use a single  to prevent "hanging"
    #  -p "[?] Press [ENTER] to keep ALL, type anything for a NEW one: " -r REPLY
    ask "Press [ENTER] to keep ALL, type anything for a NEW one: "    
    IFS= read -n 1 -s REPLY
    if [[ -z "$REPLY" ]]; then
        SECRET=$OLD_SECRET
        # 1. Filter out the 'docker' line itself and any new section headers like [new_param]
        USER_CONFIG=$(sed -n '/docker =/,$p' "$CONFIG_FILE" | grep -vE "docker =|\[" | sed '/^$/d')    
        [ -n "$USER_CONFIG" ] && USER_CONFIG=$'\n'"$USER_CONFIG"
    
    info "Existing users and secrets restored."
    else
        SECRET=$(openssl rand -hex 16)
        USER_CONFIG="" # Reset if the user wants a clean start
        info "New secret generated: $SECRET"; warn "Old additional users cleared."
    fi
else
    # Generate a fresh secret if no config exists
    SECRET=$(openssl rand -hex 16)
    USER_CONFIG="" # Reset if the user wants a clean start
    info "New secret generated: $SECRET"; warn "Old additional users cleared."
fi

# --- Custom setup parameters ---
# - PORT: The TCP port the proxy listens on (verified via lsof)
# - SITE: TLS domain for traffic masking (cloaking)
# - AD_TAG: Promotion tag for @MTProxybot registration
if [ "$OVERWRITE" = false ]; then
    # Start a loop to ensure the selected port is actually available
    while true; do
    # read -p "[?] Enter port (default $PORT): " input_port
    ask "Enter port (default $PORT): "; read -r input_port
        PORT=${input_port:-$PORT}
        if lsof -i :"$PORT" -sTCP:LISTEN -t >/dev/null ; then
            warn "Port $PORT is already occupied!"
            lsof -i :"$PORT" -sTCP:LISTEN
            echo -e "${YELLOW}Please choose a different port or stop the service above OR Turn OFF current Proxy ${NC}"
        else
            info "Port $PORT is available."
            break
        fi
    done
    
    # read -p "[?] Enter domain (default $SITE): " input_site
    ask "Enter domain (default $SITE): "; read -r input_site
    SITE=${input_site:-$SITE}    
    # Display connection details for the user before Ad_tag prompt
    echo -e "\n${CYAN}- To set up an Ad Tag, provide the settings above to @MTProxybot - ${NC}"
    echo -e "IP:Port: ${GREEN}$(get_public_ip):$PORT${NC}"
    echo -e "Secret:  ${GREEN}$SECRET${NC}"
    echo -e "${CYAN}--------------------------------${NC}"
    # fix  me
    # read -p "[?] Enter Ad_tag (press ENTER to skip): " input_tag
    # ask "Enter Ad_tag (press ENTER to skip): "; read -r input_tag
    AD_TAG=${input_tag:-$AD_TAG}   
fi

if command -v ufw >/dev/null && ufw status | grep -q "active"; then
    info "Opening port $PORT..."
    ufw allow "$PORT"/tcp
fi

# --- Multiple Users Setup ---
# MAX_USERS=16

if [ "$OVERWRITE" = false ]; then
    # Используем переменную в тексте вопроса
    read -p "[?] How many additional users to add? (0-$MAX_USERS, default 0): " user_count
    user_count=${user_count:-0}
    
    if (( user_count > MAX_USERS )); then 
        user_count=$MAX_USERS
        echo -e "${YELLOW}[!] Limited to $MAX_USERS users.${NC}"
    fi

    for (( i=1; i<=user_count; i++ )); do
        echo -e "${YELLOW}[!] If you just press Enter, the name will be Bastard$i${NC}"
        read -p "[?] Enter name for user $i: " u_name              
        u_name=${u_name:-Bastard$i}        
        new_secret=$(openssl rand -hex 16)
        USER_CONFIG+=$'\n'"$u_name = \"$new_secret\""
        info "Added $u_name with secret: $new_secret"
    done
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
classic = $PROTO_CLASSIC
secure = $PROTO_SECURE
tls = $PROTO_TLS
[server]
port = $PORT
listen_addr_ipv4 = "0.0.0.0"
listen_addr_ipv6 = "::"
metrics_port = 9090
metrics_whitelist = ["0.0.0.0"]
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
docker = "$SECRET"$USER_CONFIG
EOF

cat > "$COMPOSE_FILE" <<EOF
services:
  telemt:
    image: $IMAGE_NAME
    container_name: telemt
    restart: unless-stopped
    volumes:
      - ./$CONFIG_FILE:/etc/telemt.toml:ro
#    ports:
#      - "$PORT:$PORT/tcp"
#      - "127.0.0.1:9090:9090/tcp"
    network_mode: "host"
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

# --- Execution ---
# deploy_container && { echo -e "\n🎉 Proxy is ready to use!"; }
deploy_container && { info "🎉 Proxy is ready to use!"; }
# --- Status ---
is_running && print_proxy_link "$PORT" "$SECRET" || info "Status: Stopped. Use Option 3 later."

#mn#
