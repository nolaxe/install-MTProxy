#!/bin/bash
set -e

#   Configuration  
PORT="4433"
SITE="google.com"
IMAGE="whn0thacked/telemt-docker:latest"

#   Colors  
GREEN='\033[0;32m'
NC='\033[0m'

#   UI  
clear
echo -e "${GREEN}Telemt MTProxy Installer${NC}\n"

# Input configuration
read -p "Enter port (default $PORT): " input_port
PORT=${input_port:-$PORT}
read -p "Enter domain (default $SITE): " input_site
SITE=${input_site:-$SITE}

# Generate credentials
SECRET="dd$(openssl rand -hex 16)"

# Create telemt.toml
cat > telemt.toml <<EOF
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
user = "$SECRET"
EOF

# Create docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  telemt:
    image: $IMAGE
    container_name: telemt
    restart: unless-stopped
    volumes:
      - ./telemt.toml:/etc/telemt.toml:ro
    ports:
      - "$PORT:$PORT/tcp"
EOF

# Deployment
echo -e "\n${GREEN}Pulling and starting container...${NC}"
# docker compose pull && docker compose up -d
 docker compose pull >/dev/null 2>&1
 docker compose up -d
 docker image prune -f >/dev/null 2>&1
# docker info
 docker ps -a --filter "name=telemt" --format "Container status: {{.Status}}"
 docker images whn0thacked/telemt-docker --format "IMAGE: ID: {{.ID}} | Created: {{.CreatedAt}}"

# Output
IP=$(curl -s --max-time 5 ifconfig.me || echo "YOUR_IP")
echo -e "\n--------------------------------------------------------------------------------------------"
echo -e "Proxy link: ${GREEN}tg://proxy?server=$IP&port=$PORT&secret=$SECRET${NC}"
