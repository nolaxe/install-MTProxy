#!/bin/bash
# vibe coding !!!

# Установка/Удаление Telemt MTProxy (Native Version)
[ "$EUID" -ne 0 ] && { echo -e "[ERROR] Запустите от имени root"; exit 1; }

# --- Настройки ---
PORT="4431"
SITE="google.com"
INSTALL_DIR="/root/telemt-mini"
SERVICE_NAME="telemt-mini"
CONFIG_FILE="$INSTALL_DIR/telemt.toml"
SECRET="1981e8e8f5a09a1bc57b49c1a9f352af" # Фиксированный секрет пользователя

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

# --- Меню ---
clear
echo -e "${CYAN}Telemt Native Manager (v3.1)${NC}"
echo "1) Установить / Обновить"
echo "2) Полное удаление"
ask "Выберите опцию: "; read -r OPTION

case $OPTION in
    2)
        warn "Удаление службы $SERVICE_NAME..."
        systemctl stop $SERVICE_NAME 2>/dev/null
        systemctl disable $SERVICE_NAME 2>/dev/null
        rm -f /etc/systemd/system/$SERVICE_NAME.service
        systemctl daemon-reload

        if [ -f "$CONFIG_FILE" ]; then
            OLD_PORT=$(grep "port =" "$CONFIG_FILE" | awk -F'=' '{print $2}' | tr -d '[:space:]"')
            [ -n "$OLD_PORT" ] && command -v ufw >/dev/null && ufw delete allow "$OLD_PORT"/tcp
        fi
        info "Удаление завершено."
        exit 0
        ;;
    1)
        info "Запуск установки..."
        ;;
    *)
        err "Неверный выбор"; exit 1
        ;;
esac

# --- Логика установки ---

# 1. Подготовка папки
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# 2. Определение архитектуры
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  FILE_TAG="x86_64-linux-musl" ;;
    aarch64) FILE_TAG="aarch64-linux-musl" ;;
    *)       err "Архитектура $ARCH не поддерживается"; exit 1 ;;
esac

# 3. Скачивание актуального релиза через GitHub API
info "Поиск последней версии для $ARCH..."
URL=$(curl -s https://api.github.com/repos/telemt/telemt/releases/latest | grep "browser_download_url" | grep "$FILE_TAG.tar.gz" | head -n 1 | cut -d '"' -f 4)

if [ -z "$URL" ]; then
    warn "Не удалось получить ссылку через API. Пробую прямую ссылку..."
    URL="https://github.com/telemt/telemt/releases/download/v1.0.0/telemt-$FILE_TAG.tar.gz"
fi

info "Загрузка: $URL"
curl -L "$URL" -o "telemt.tar.gz" || { err "Загрузка не удалась"; exit 1; }

# Распаковка и очистка
tar -xzf "telemt.tar.gz"
rm -f "telemt.tar.gz"
chmod +x telemt

# 4. Настройка параметров
ask "Введите порт (по умолчанию $PORT): "; read -r input_port
PORT=${input_port:-$PORT}
ask "Введите домен для TLS (по умолчанию $SITE): "; read -r input_site
SITE=${input_site:-$SITE}

# 5. Генерация конфига
cat > "$CONFIG_FILE" <<EOF
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
tls_domain = "$SITE"
mask = true
[access.users]
user1 = "$SECRET"
EOF

# 6. Создание системной службы
info "Создание службы systemd..."
cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Telemt MTProxy Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/telemt -c $CONFIG_FILE
Restart=always
RestartSec=3
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# 7. Запуск службы
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

# 8. Firewall (UFW)
if command -v ufw >/dev/null && ufw status | grep -q "active"; then
    ufw allow "$PORT"/tcp
fi

# 9. Генерация и вывод ссылки
ip=$(get_public_ip)
domain_hex=$(echo -n "$SITE" | od -A n -t x1 | tr -d ' \n')
full_secret="ee${SECRET}${domain_hex}"
link="tg://proxy?server=$ip&port=$PORT&secret=$full_secret"

echo -e "\n${GREEN}🎉 Установка завершена успешно!${NC}"
echo -e "🔗 Ссылка для Telegram: ${CYAN}$link${NC}"
