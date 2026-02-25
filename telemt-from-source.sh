#!/bin/bash

# Build from source - Telemt a fast Rust-based MTProxy (MTProto) server
# Usage:
# chmod +x ./telemt-from-source.sh
# ./telemt-from-source.sh

# --- Configuration ---
REPO_URL="https://github.com/telemt/telemt.git"
REPO_DIR="/root/telemt_src"

PORT="4433"
SITE="google.com"
CONFIG_FILE="config.toml"
COMPOSE_FILE="docker-compose.yml"

mkdir -p "$REPO_DIR"
cd "$REPO_DIR" || { echo "ERROR"; exit 1; }

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

get_public_ip() {
    curl -s --max-time 5 ifconfig.me || echo "YOUR_IP"
}

print_proxy_link() {
    local p=$1 s=$2 site_name=$3
    local ip=$(get_public_ip)
    local domain_hex=$(echo -n "$site_name" | od -A n -t x1 | tr -d ' \n')
    local full_secret="ee${s}${domain_hex}"
    
    local link="tg://proxy?server=$ip&port=$p&secret=$full_secret"
    echo "$link" > "proxy_link.txt"
    #
    echo -e "=========================================================="
    echo -e "Copy the link below to Telegram and click it to activate the proxy"
    echo -e "🔗 ${CYAN}${link}${NC}"
    echo -e "=========================================================="
}

# --- Initialization ---
clear
echo -e "${GREEN}=== Telemt Custom Distroless Builder ===${NC}"
echo -e "${CYAN}Source :${NC} $REPO_URL"

if [ -d "$REPO_DIR" ]; then
    echo -e "Status:"
    cd "$REPO_DIR" && docker compose ps
    cd - > /dev/null

else
    warn "Repository directory not found. Please select 'Install' (1)."
fi

# Check for Docker
if ! command -v docker >/dev/null 2>&1; then
    warn "Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

# --- Menu ---
echo -e "\nSelect Action:"
echo -e " 1) ${CYAN}Install${NC}"
echo -e " 2) ${GREEN}Get Proxy Link${NC}"
echo -e " 3) ${YELLOW}Stop/Start/Status${NC}"
echo -e " 4) ${RED}Uninstall${NC}"
echo -ne "\n${YELLOW}Choose option [1-4]:${NC} "
read -r CHOICE

case $CHOICE in
    1)
        read -p "> Enter port (default $PORT): " input_port
        PORT=${input_port:-$PORT}
        read -p "> Enter domain (default $SITE): " input_site
        SITE=${input_site:-$SITE}
        SECRET=$(openssl rand -hex 16)
        
        info "[1/3] Cleaning up and cloning repository..."
        rm -rf ./* .git 2>/dev/null
        git clone --depth 1 "$REPO_URL" . 
        info "[2/3] Creating configuration files..."

        # Dockerfile
        cat > Dockerfile.hardened <<EOF
FROM rust:alpine AS builder
RUN apk add --no-cache musl-dev git
WORKDIR /usr/src/telemt
COPY . .
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM gcr.io/distroless/static-debian12:latest
USER 1000:1000
COPY --from=builder /usr/src/telemt/target/x86_64-unknown-linux-musl/release/telemt /usr/local/bin/telemt
ENTRYPOINT ["telemt", "-c", "/etc/telemt.toml"]
EOF

        # Config.toml
        cat > "$CONFIG_FILE" <<EOF
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
[[server.listeners]]
ip = "0.0.0.0"
[censorship]
tls_domain = "$SITE"
mask = true
[access.users]
docker = "$SECRET"
EOF

        # Docker-compose
        cat > "$COMPOSE_FILE" <<EOF
services:
  telemt:
    build:
      context: .
      dockerfile: Dockerfile.hardened
    container_name: telemt
    #
    restart: unless-stopped
    volumes:
      - ./$CONFIG_FILE:/etc/telemt.toml:ro
    ports:
      - "${PORT}:${PORT}/tcp"
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
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
EOF

        info "[3/3] Building and starting (Wait ~3-5 min)..."
        docker compose up -d --build
        
        info "Success!"
        print_proxy_link "$PORT" "$SECRET" "$SITE"
        ;;

    2)
        if [ -d "$REPO_DIR" ] && [ -f "$REPO_DIR/$CONFIG_FILE" ]; then
            cd "$REPO_DIR"
            S_PORT=$(grep "port =" "$CONFIG_FILE" | head -1 | awk -F'=' '{print $2}' | tr -d ' ')
            S_SEC=$(grep "docker =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' "')
            S_SITE=$(grep "tls_domain =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' "')
            print_proxy_link "$S_PORT" "$S_SEC" "$S_SITE"
        else
            err "Not installed."
        fi
        ;;

    3)
        if [ -d "$REPO_DIR" ]; then
            cd "$REPO_DIR"
            echo "Current status:"
            docker compose ps
            echo -e "\n1) Stop  2) Start  3) Restart"
            read -p "Action: " ACT
            [[ $ACT == "1" ]] && docker compose stop
            [[ $ACT == "2" ]] && docker compose start
            [[ $ACT == "3" ]] && docker compose restart
        fi
        ;;

    4)
        if [ -d "$REPO_DIR" ]; then
            cd "$REPO_DIR"
            docker compose down --rmi all
            OLD_PORT=$(grep "port =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d ' ' 2>/dev/null)
            [ -n "$OLD_PORT" ] && command -v ufw >/dev/null && ufw delete allow "$OLD_PORT"/tcp >/dev/null
            cd ..
            rm -rf "$REPO_DIR"
            info "Removed everything."
        fi
        ;;
    *)
        err "Invalid choice."
        ;;
esac
#mn#
