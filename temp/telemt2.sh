1#!/bin/bash

#  Configuration 
PORT="4433"
SITE="google.com"
CONFIG_FILE="telemt.toml"
COMPOSE_FILE="docker-compose.yml"
IMAGE_NAME="whn0thacked/telemt-docker:latest"
OVERWRITE=true

#  Colors 
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

#  Functions 
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
    echo -e "=========================================================="
    echo -e "🔗 LINK: ${CYAN}tg://proxy?server=$ip&port=$p&secret=$s${NC}"
    echo -e "=========================================================="
}

deploy_container() {
    info "Pulling and starting container..."
    docker compose pull && docker compose up -d --remove-orphans
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

#  Initialization 
set -e
clear
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║             Telemt MTProxy Installer               ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

is_running && echo -e "Status: ${GREEN}Running !!!${NC}\n"

echo -e "Select action:"
echo -e " 1) ${CYAN}Fast Install${NC}     (Port: $PORT, Domain: $SITE)"
echo -e " 2) ${CYAN}Manual Install${NC}   (Custom settings)"
if is_running; then
    echo -e " 3) ${YELLOW}Stop Proxy${NC}       Status: ${GREEN}Running${NC}"
else
    echo -e " 3) ${YELLOW}Start Proxy${NC}      Status: ${RED}Stopped${NC}"
fi
echo -e " 4) ${RED}Full Uninstall${NC}"
echo -ne "\n${YELLOW}Choose option [1-4]:${NC} "
read -r INSTALL_MODE

#  Logic Selection 
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
            err "Not installed yet."
        fi
        exit 0 ;;
    4)
        warn "This will remove EVERYTHING."
        read -p "Are you sure? [ENTER] to confirm or type anything to cancel: " -r; echo
        if [[ -z $REPLY ]]; then
            [ -f "$COMPOSE_FILE" ] && docker compose down --rmi all
            rm -f "$CONFIG_FILE" "$COMPOSE_FILE"
            info "Uninstall complete."
        fi
        exit 0 ;;
    *) err "Invalid option."; exit 1 ;;
esac

#  Dependency & Config 
command -v openssl >/dev/null || { info "Installing openssl..."; apt-get update && apt-get install -y openssl; }
command -v docker >/dev/null || { err "Docker not found."; exit 1; }

if [ "$OVERWRITE" = false ]; then
    read -p "> Enter port (default $PORT): " input_port
    PORT=${input_port:-$PORT}
    read -p "> Enter domain (default $SITE): " input_site
    SITE=${input_site:-$SITE}
fi

if command -v ufw >/dev/null && ufw status | grep -q "active"; then
    info "Opening port $PORT..."
    ufw allow "$PORT"/tcp
fi

#  File Generation 
prepare_files
info "Generating configuration..."
SECRET="dd$(openssl rand -hex 16)"

cat > "$CONFIG_FILE" <<EOF
show_link = ["docker"]
[general]
fast_mode = true
tls = true
[server]
port = $PORT
listen_addr_ipv4 = "0.0.0.0"
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
    read -p "> 🚀 Start now? [ENTER] to confirm or type anything to cancel: " -r; echo
    [[ -z $REPLY ]] && deploy_container
fi

# Output
echo -e "\n🎉 Done!"
if is_running; then
    print_proxy_link "$PORT" "$SECRET"
else
    info "Status: Stopped. Use option 3 to start."
fi
