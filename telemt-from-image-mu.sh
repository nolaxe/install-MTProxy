# --- TLS vs Secure Mode Selection (Custom Install Only) ---
if [ "$OVERWRITE" = false ]; then
    echo -e "\n${CYAN}Select proxy mode:${NC}"
    echo -e " 1) ${GREEN}TLS Mode${NC}     (tls = true, secure = false)  - Standard TLS cloaking"
    echo -e " 2) ${YELLOW}Secure Mode${NC}  (tls = false, secure = true) - Enhanced security mode\n"
    ask "Choose mode [1 or 2] (default 1): "; read -r mode_choice
    mode_choice=${mode_choice:-1}
    
    if [ "$mode_choice" = "2" ]; then
        TLS_MODE=false
        SECURE_MODE=true
        info "Mode selected: Secure (secure = true, tls = false)"
    else
        TLS_MODE=true
        SECURE_MODE=false
        info "Mode selected: TLS (tls = true, secure = false)"
    fi
else
    # Fast Install defaults
    TLS_MODE=true
    SECURE_MODE=false
fi

