#!/bin/bash
# Проверка сколько сервисов telemt выдержит сервер
# Установка последовательно новых инстансев

[ "$EUID" -ne 0 ] && { echo -e "[ERROR] Запустите от имени root"; exit 1; }

# --- Базовые настройки ---
BASE_INSTALL_DIR="/root/telemt-instances"
SECRET="1981e8e8f5a09a1bc57b49c1a9f352af"
DEFAULT_SITE="google.com"
START_PORT=4430 

# Генерируем уникальный ID для этой установки
INSTANCE_ID="telemt-$(head /dev/urandom | tr -dc a-z0-9 | head -c 4)"
INSTALL_DIR="$BASE_INSTALL_DIR/$INSTANCE_ID"
SERVICE_NAME="telemt-$INSTANCE_ID"

# --- Цвета ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; } 
err()   { echo -e "${RED}[ERROR]${NC} $*"; }
ask()   { echo -ne "${YELLOW}[?]${NC} $*"; }

get_public_ip() { curl -4 -s --max-time 5 ifconfig.me || echo "YOUR_IP"; }

# Функция поиска свободного порта
find_free_port() {
    local port=$START_PORT
    while ss -tuln | grep -q ":$port "; do
        ((port++))
    done
    echo "$port"
}
list_active_proxies() {
    echo -e "\n${CYAN}=== Список запущенных Telemt прокси ===${NC}"
    services=$(systemctl list-units --type=service --state=running --no-legend --no-pager | awk '{print $1}' | grep "^telemt-telemt-")
    
    if [ -z "$services" ]; then
        echo "Нет активных инстансов."
    else
        printf "%-28s %-10s %-15s %s\n" "ID Службы" "Порт" "Домен" "Ссылка"
        echo "------------------------------------------------------------------------------------------------------"
        for svc in $services; do

            config_path=$(systemctl show -p ExecStart "$svc" | sed -n 's/.*-c \(.*.toml\).*/\1/p' | xargs)
            
            if [ -f "$config_path" ]; then
                port=$(grep "port =" "$config_path" | awk -F'=' '{print $2}' | tr -d '[:space:]"')
                domain=$(grep "tls_domain =" "$config_path" | awk -F'=' '{print $2}' | tr -d '[:space:]"' | tr -d "'\"")
                ip=$(get_public_ip)
                domain_hex=$(echo -n "$domain" | od -A n -t x1 | tr -d ' \n')
                link="tg://proxy?server=$ip&port=$port&secret=ee${SECRET}${domain_hex}"
                printf "${CYAN}%-28s${NC} %-10s %-15s %s\n" "$svc" "$port" "$domain" "$link"
            else
                inst_id=$(echo "$svc" | sed 's/\.service//')
                alt_path="/root/telemt-instances/${inst_id#telemt-}/telemt.toml"
                if [ -f "$alt_path" ]; then
                     # (повтор логики чтения из alt_path)
                     port=$(grep "port =" "$alt_path" | awk -F'=' '{print $2}' | tr -d '[:space:]"')
                     domain=$(grep "tls_domain =" "$alt_path" | awk -F'=' '{print $2}' | tr -d '[:space:]"' | tr -d "'\"")
                     ip=$(get_public_ip)
                     domain_hex=$(echo -n "$domain" | od -A n -t x1 | tr -d ' \n')
                     link="tg://proxy?server=$ip&port=$port&secret=ee${SECRET}${domain_hex}"
                     printf "${CYAN}%-28s${NC} %-10s %-15s %s\n" "$svc" "$port" "$domain" "$link"
                fi
            fi
        done
    fi
    echo "------------------------------------------------------------------------------------------------------"
}

# --- Меню ---
clear
echo -e "${CYAN}Telemt Multi-Manager (v3.3)${NC}"
echo "1) Установить НОВЫЙ инстанс (авто-порт)"
echo "2) Удалить ВСЕ инстансы"
echo "3) Список запущенных"
ask "Выберите опцию: "; read -r OPTION

case $OPTION in
    2)
        warn "Полная очистка всех служб telemt..."
        for svc in $(systemctl list-units --type=service --all | grep "telemt-telemt-" | awk '{print $1}'); do
            systemctl stop "$svc"
            systemctl disable "$svc"
            rm -f "/etc/systemd/system/$svc"
        done
        systemctl daemon-reload
        rm -rf "$BASE_INSTALL_DIR"
        info "Все экземпляры удалены."
        exit 0
        ;;
    3)
        list_active_proxies
        exit 0
        ;;
    *)
        info "Подготовка нового инстанса: $INSTANCE_ID"
        ;;
esac

# --- Автоматическая логика установки ---

# 1. Авто-выбор порта
PORT=$(find_free_port)
info "Использую свободный порт: $PORT"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# 2. Определение архитектуры
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  FILE_TAG="x86_64-linux-musl" ;;
    aarch64) FILE_TAG="aarch64-linux-musl" ;;
    *)       err "Архитектура $ARCH не поддерживается"; exit 1 ;;
esac

# 3. Загрузка бинарника
info "Загрузка последней версии..."
URL=$(curl -s https://api.github.com/repos/telemt/telemt/releases/latest | grep "browser_download_url" | grep "$FILE_TAG.tar.gz" | head -n 1 | cut -d '"' -f 4)
[ -z "$URL" ] && URL="https://github.com/telemt/telemt/releases/download/v1.0.0/telemt-$FILE_TAG.tar.gz"

curl -L "$URL" -o "telemt.tar.gz" && tar -xzf "telemt.tar.gz" && rm "telemt.tar.gz"
chmod +x telemt

# 4. Генерация конфига
cat > "$INSTALL_DIR/telemt.toml" <<EOF
show_link = ["user1"]
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
[[server.listeners]]
ip = "0.0.0.0"
[censorship]
tls_domain = "$DEFAULT_SITE"
mask = true
[access.users]
user1 = "$SECRET"
EOF

# 5. Создание службы
info "Регистрация в systemd..."
cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Telemt MTProxy ($INSTANCE_ID)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/telemt -c $INSTALL_DIR/telemt.toml
Restart=always
RestartSec=3
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# 6. Firewall
if command -v ufw >/dev/null && ufw status | grep -q "active"; then
    ufw allow "$PORT"/tcp
fi

echo -e "\n${GREEN}✔ Готово! Новый прокси поднят.${NC}"

# Финальный вывод всех прокси
list_active_proxies
