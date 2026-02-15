#!/bin/bash

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Functions ---
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${RED}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

get_public_ip() {
    curl -s --max-time 5 ifconfig.me || echo "YOUR_IP"
}

create_index() {
    info "Creating stylish Under Construction page..."
    sudo mkdir -p /var/www/html
    sudo tee /var/www/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Under Construction</title>
    <style>
        body { background: #1a1a1a; color: #fff; font-family: 'Segoe UI', sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; overflow: hidden; }
        .container { text-align: center; border: 2px dashed #f1c40f; padding: 50px; border-radius: 20px; }
        h1 { font-size: 3rem; margin-bottom: 10px; }
        p { color: #888; font-size: 1.2rem; }
        .icon { font-size: 5rem; animation: pulse 2s infinite; }
        @keyframes pulse { 0% { transform: scale(1); } 50% { transform: scale(1.1); } 100% { transform: scale(1); } }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🏗️</div>
        <h1>Under Construction</h1>
        <p>We are building something amazing. Please come back later!</p>
    </div>
</body>
</html>
EOF
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html
}

# --- UI Setup ---
clear
echo -e "${CYAN}╔════════════════════════════════════════╗"
echo -e "║      Nginx Manager Script              ║"
echo -e "╚════════════════════════════════════════╝${NC}"

if systemctl is-active --quiet nginx; then
    echo -e "Status: Nginx ${GREEN}Running${NC}"
else
    echo -e "Status: Nginx ${RED}Not Running / Not Installed${NC}"
fi

echo -e "\nSelect action:"
echo -e " 1) ${GREEN}Install Nginx${NC}"
echo -e " 2) ${RED}Uninstall Nginx${NC} (Full cleanup)"
echo -e " 3) ${YELLOW}Update index.html${NC}"

echo -ne "\n${YELLOW}Choose option [1-3]:${NC} "
read -r OPTION

case $OPTION in
    1)
        info "Starting Nginx installation..."
        # sudo apt update
        sudo apt install -y nginx-light
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        info "Installation complete!"
        ;;
    2)
        warn "This will REMOVE Nginx and all files in /var/www/html"
        echo -ne "${YELLOW}Press [ENTER] to confirm or type anything to cancel: ${NC}"
        read -r CONFIRM
        
        if [[ -z "$CONFIRM" ]]; then
            info "Uninstalling..."
            sudo apt purge nginx nginx-common nginx-full -y
            sudo apt autoremove -y
            sudo rm -rf /etc/nginx /var/www/html
            info "Nginx fully removed."
        else
            info "Uninstall cancelled."
        fi
        ;;
    3)
        if command -v nginx >/dev/null || [ -d "/var/www/html" ]; then
            create_index
            info "Page updated successfully."
        else
            err "Nginx not found. Install it first (option 1)."
        fi
        ;;    
    *)
        err "Invalid choice."
        exit 1
        ;;
esac

# --- Final Status ---
if systemctl is-active --quiet nginx; then
    IP=$(get_public_ip)
    echo -e "\n----------------------------------------------------------"
    echo -e "🔗 Website: ${CYAN}http://$IP/${NC}"
    echo -e "----------------------------------------------------------"
fi
