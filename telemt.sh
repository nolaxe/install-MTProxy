#!/bin/bash

# Distroless Image for Telemt - a fast Rust-based MTProxy (MTProto) server
# Usage:
# chmod +x ./telemt.sh
# ./telemt.sh

# --- Configuration ---
PORT="4433"
SITE="google.com"

CONFIG_FILE="telemt.toml"
COMPOSE_FILE="docker-compose.yml"

AD_TAG="000empty000" # Default Promotion Tag

# docker images:
# Distroless build of https://github.com/telemt/telemt by whn0thacked
# IMAGE_NAME="whn0thacked/telemt-docker:latest" # https://github.com/An0nX/telemt-docker/blob/master/README.md

# Distroless build of https://github.com/telemt/telemt by whn0thacked (Копия)
# IMAGE_NAME="exalon/telemt-docker:latest"  # https://hub.docker.com/repository/docker/exalon/telemt-docker/general

# new Distroless cборка https://github.com/telemt/telemt 
IMAGE_NAME="exalon/telemt:latest"  # https://hub.docker.com/repository/docker/exalon/telemt/general

# REPO_URL="https://github.com/telemt/telemt.git"
OVERWRITE=true

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Functions ---
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; } 
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

is_running() {
    [ "$(docker inspect -f '{{.State.Running}}' telemt 2>/dev/null)" == "true" ]
}

get_public_ip() {
    curl -s --max-time 5 ifconfig.me || echo "YOUR_IP"
}

print_proxy_link() {
    local p=$1 s=$2
    local ip=$(get_public_ip)
    # Кодируем домен в hex (google.com -> 676f6f676c652e636f6d)
    local domain_hex=$(echo -n "$SITE" | od -A n -t x1 | tr -d ' \n')
    # Склеиваем префикс 'ee' + секрет + hex домена
    local full_secret="ee${s}${domain_hex}"
	
    echo -e "=========================================================="
    echo -e "🔗 LINK: ${CYAN}tg://proxy?server=$ip&port=$p&secret=$full_secret${NC}"
	echo -e "=========================================================="
}

deploy_container() {
    info "Pulling and starting container..."
    # docker compose pull 
	# docker compose up -d --remove-orphans
	docker compose up -d --force-recreate --remove-orphans
}

prepare_files() {
    for file in "$CONFIG_FILE" "$COMPOSE_FILE"; do
        if [ -f "$file" ]; then
            if [ "$OVERWRITE" = false ]; then
                read -p "   $file exists. [ENTER] to confirm or type anything to cancel: " -r; echo
                [[ -n $REPLY ]] && { err "Cancelled."; exit 1; }
            fi
            rm "$file"
        fi
    done
}

# --- Initialization ---
set -e
clear
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║              MTProxy (Telemt) Installer            ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}image: $IMAGE_NAME\n"

# --- Docker Check & Installation ---
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] Docker not found. Starting installation...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo -e "${GREEN}[OK] Docker installed successfully.${NC}"
else
    # Start Docker if the service is inactive
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}[!] Docker service found but not running. Starting...${NC}"
        systemctl start docker
    fi
fi

# Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] Docker Compose plugin not found. Installing...${NC}"
    apt-get update && apt-get install -y docker-compose-plugin
fi


# --- Menu ---
is_running && echo -e "Status: ${GREEN}Running !!!${NC}\n"

echo -e "Select action: "
echo -e " 1) Fast Install     (Port: $PORT, Domain: $SITE)"
echo -e " 2) ${CYAN}Custom Install${NC}   (Custom settings)"
if is_running; then
    echo -e " 3) ${YELLOW}Stop Proxy${NC}      (Current status: ${GREEN}Running${NC})"
else
    echo -e " 3) ${YELLOW}Stop\Start Proxy${NC} (Current status: ${RED}Stopped\Not installed${NC})"
fi
echo -e " 4) ${RED}Full Uninstall${NC}"
echo -ne "\n${YELLOW}Choose option [1-4]:${NC} "
read -r INSTALL_MODE

# --- Logic Selection ---
case $INSTALL_MODE in
    1) info "Mode: Fast Install" ;;
    2) OVERWRITE=false; info "Mode: Manual Install" ;;
    3)
        if [ -f "$COMPOSE_FILE" ]; then
            if is_running; then
                docker compose stop && info "Stopped."
            else
                deploy_container
                S_PORT=$(grep "port =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
                S_SEC=$(grep "docker =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' "')
                print_proxy_link "$S_PORT" "$S_SEC"
            fi
        else
            err "Proxy is not installed yet"
        fi
        exit 0 ;;
    4)
        warn "This will remove EVERYTHING related to Telemt"
        read -p "[?] Are you sure? [ENTER] to confirm or type anything to cancel: " -r; echo
        if [[ -z $REPLY ]]; then
		## удаление правил из UFW
			if [ -f "$CONFIG_FILE" ]; then
                OLD_PORT=$(grep "port =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ')
                if [ -n "$OLD_PORT" ] && command -v ufw >/dev/null; then
                    info "Closing port $OLD_PORT in UFW..."
                    ufw delete allow "$OLD_PORT"/tcp || true
                fi
            fi		
		## 
            [ -f "$COMPOSE_FILE" ] && docker compose down --rmi all
            rm -f "$CONFIG_FILE" "$COMPOSE_FILE"
            info "Uninstall complete."
        fi
        exit 0 ;;
    *) err "Invalid option."; exit 1 ;;
esac

# --- Dependencies & Configuration ---
command -v openssl >/dev/null || { info "Installing openssl..."; apt-get update && apt-get install -y openssl; }
command -v docker >/dev/null || { err "Docker not found."; exit 1; }

# --- Secret Management ---
if [ -f "$CONFIG_FILE" ]; then
    OLD_SECRET=$(grep "docker =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' "')
    echo -e "${YELLOW}[?] Config found. Use existing secret? ($OLD_SECRET)${NC}"
    read -p "   [ENTER] to keep current, type anything for a NEW one: " -r
    if [[ -z $REPLY ]]; then
        SECRET=$OLD_SECRET
        info "Keeping existing secret."
    else
        SECRET=$(openssl rand -hex 16)
        info "New secret generated: $SECRET"
    fi
else
    SECRET=$(openssl rand -hex 16)
    info "Generated secret: $SECRET"
fi

# --- Manual Configuration ---
if [ "$OVERWRITE" = false ]; then
    # read -p "> Enter port (default $PORT): " input_port
    # PORT=${input_port:-$PORT}
	
	# Start a loop to ensure the selected port is actually available
    while true; do
        read -p "> Enter port (default $PORT): " input_port
        PORT=${input_port:-$PORT}

        # Check if the port is already in use by any process
        # lsof returns 0 if the port is busy, so we trigger the warning
        if lsof -i :"$PORT" -sTCP:LISTEN -t >/dev/null ; then
            warn "Port $PORT is already occupied!"
            # Show the user which process is holding the port
            lsof -i :"$PORT" -sTCP:LISTEN
            echo -e "${YELLOW}Please choose a different port or stop the service above.${NC}"
        else
            # Port is free, proceed with the installation
            info "Port $PORT is available."
            break
        fi
    done
		
    read -p "> Enter domain (default $SITE): " input_site
    SITE=${input_site:-$SITE}
    
	# Display connection details for the user before Ad_tag prompt
    echo -e "\n${CYAN}--- Current Proxy Connection for @MTProxybot---${NC}"
    echo -e "IP:Port: ${GREEN}$(get_public_ip):$PORT${NC}"
    echo -e "Secret:  ${GREEN}$SECRET${NC}"
    echo -e "${CYAN}--------------------------------${NC}"    

    # Prompt for Ad_tag (Promotion tag)
    read -p "> Enter Ad_tag (press ENTER to skip): " input_tag
    AD_TAG=${input_tag:-$AD_TAG}	
fi

if command -v ufw >/dev/null && ufw status | grep -q "active"; then
    info "Opening port $PORT..."
    ufw allow "$PORT"/tcp
fi

# --- File Generation ---
prepare_files
info "Generating configuration files..."

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
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp:rw,nosuid,nodev,noexec,size=16m
EOF

#  Execution 
if [ "$OVERWRITE" = true ]; then
    deploy_container
else

	read -p "$(echo -e "> 🚀 ${GREEN}Start now?${NC} [ENTER] to confirm: ")" -r; echo    
    [[ -z $REPLY ]] && deploy_container
fi

# Output
echo -e "\n🎉 Done!"
if is_running; then
    print_proxy_link "$PORT" "$SECRET"
else
    info "Status: Stopped. Use option 3 to start the proxy."
fi
