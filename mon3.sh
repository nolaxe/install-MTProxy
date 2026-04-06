#!/bin/bash

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Eye candy
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ACHTUNG]${NC} $*"; }

API_URL="http://127.0.0.1:9091/v1/users"
RESPONSE=$(curl -s "$API_URL")

# Проверка на пустой ответ
if [[ -z "$RESPONSE" || "$RESPONSE" == "null" ]]; then
    err "API не отвечает. Проверь: curl $API_URL"
    exit 1
fi

# Сбор статистики заранее для вывода сверху
TOTAL_CONNS=$(echo "$RESPONSE" | jq '[.data[]?.current_connections // 0] | add')
TOTAL_RECENT=$(echo "$RESPONSE" | jq '[.data[]?.recent_unique_ips // 0] | add')

echo -e "${CYAN}--- Telemt Proxy Status ---${NC}"
info "Активных соединений: $TOTAL_CONNS"
info "Уникальных IP (recent): $TOTAL_RECENT"
echo ""

# Парсинг и вывод таблицы
echo "$RESPONSE" | jq -r '
  ["USER", "CONNS", "ACT", "REC", "TRAFFIC(MB)"],
  ["----", "-----", "---", "---", "-----------"],
  (.data[]? | 
    # Объединяем активные и недавние IP, чтобы они не пропадали
    ([(.active_unique_ips_list[]? // empty), (.recent_unique_ips_list[]? // empty)] | unique) as $all_ips |
    
    # Строка пользователя
    [.username // "unknown", .current_connections // 0, .active_unique_ips // 0, .recent_unique_ips // 0, (((.total_octets // 0) / 1048576 * 100 | round) / 100)],
    
    # Список всех связанных IP
    ($all_ips[]? | [" ∟", "", "", "", .])
  ) 
  | @tsv' | column -t -s $'\t'

echo -e "${CYAN}----------------------------${NC}"
