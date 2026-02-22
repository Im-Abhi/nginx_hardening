#!/bin/bash

# CIS 2.4.1 – Ensure NGINX only listens on authorized ports
# Manual Review Mode
# Displays findings only if unauthorized ports are detected

AUTHORIZED_PORTS=("80" "443")

check_listen_ports() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local current_file=""
    local line_number=0
    local unauthorized=0
    local findings=()

    while IFS= read -r line; do

        if [[ "$line" =~ ^#\ configuration\ file\ (.*):$ ]]; then
            current_file="${BASH_REMATCH[1]}"
            line_number=0
            continue
        fi

        ((line_number++))

        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^[[:space:]]*listen[[:space:]]+ ]]; then

            [[ "$line" =~ unix: ]] && continue

            port="$(echo "$line" | sed -nE 's/^[[:space:]]*listen[[:space:]]+([^;]*:)?([0-9]{2,5}).*/\2/p')"
            [[ -z "$port" ]] && continue

            authorized=false
            for allowed in "${AUTHORIZED_PORTS[@]}"; do
                [[ "$port" == "$allowed" ]] && authorized=true && break
            done

            if [[ "$authorized" == false ]]; then
                unauthorized=1
                findings+=("Port: $port | File: $current_file | Line: $line_number | $line")
            fi
        fi

    done < <(nginx -T 2>/dev/null)

    if [[ "$unauthorized" -eq 0 ]]; then
        pass "Only authorized listen ports configured"
        return
    fi

    for entry in "${findings[@]}"; do
        printf "%s\n" "$entry"
    done

    fail "Unauthorized listen ports detected"
}