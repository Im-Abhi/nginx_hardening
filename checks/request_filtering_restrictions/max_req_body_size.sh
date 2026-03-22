#!/usr/bin/env bash

# CIS 5.2.2 – Ensure the maximum request body size is set correctly
# SAFE MODE: No override of existing explicit directives

check_client_max_body_size() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local errors=""
    local has_valid_size=0

    # Convert size to bytes
    to_bytes() {
        local val="$1"
        if [[ "$val" =~ ^([0-9]+)([kKmMgG]?)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"

            case "$unit" in
                k|K) echo $((num * 1024)) ;;
                m|M) echo $((num * 1024 * 1024)) ;;
                g|G) echo $((num * 1024 * 1024 * 1024)) ;;
                *) echo "$num" ;;
            esac
        else
            echo "invalid"
        fi
    }

    while read -r file line val; do

        if [[ "$val" == "0" ]]; then
            errors+="  - [CRITICAL] client_max_body_size in $file (line $line) is set to '0' (Unlimited).\n"
            continue
        fi

        local bytes
        bytes=$(to_bytes "$val")

        if [[ "$bytes" == "invalid" ]]; then
            errors+="  - [ERROR] Invalid syntax '$val' in $file (line $line).\n"
            continue
        fi

        # Valid configuration found
        has_valid_size=1

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*client_max_body_size[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*client_max_body_size[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, val
        }
    ')

    if [[ "$has_valid_size" -eq 0 ]]; then
        errors+="  - client_max_body_size directive is missing or invalid.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Define a reasonable upload limit (e.g., 100K–10M depending on app).\n"
        errors+="  - Example:\n"
        errors+="      client_max_body_size 100K;"
        echo -e "${errors%\\n}"
        return 1
    fi

    return 0
}

remediate_client_max_body_size() {

    command -v nginx >/dev/null 2>&1 || return 1

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local main_config="/etc/nginx/nginx.conf"
    local has_valid_size=0
    local manual_intervention_required=0

    to_bytes() {
        local val="$1"
        if [[ "$val" =~ ^([0-9]+)([kKmMgG]?)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local unit="${BASH_REMATCH[2]}"
            case "$unit" in
                k|K) echo $((num * 1024)) ;;
                m|M) echo $((num * 1024 * 1024)) ;;
                g|G) echo $((num * 1024 * 1024 * 1024)) ;;
                *) echo "$num" ;;
            esac
        else
            echo "invalid"
        fi
    }

    while read -r val; do

        if [[ "$val" == "0" ]]; then
            echo "[WARNING] client_max_body_size is set to 0 (Unlimited). Manual fix required."
            manual_intervention_required=1
            continue
        fi

        local bytes
        bytes=$(to_bytes "$val")

        if [[ "$bytes" == "invalid" ]]; then
            echo "[WARNING] client_max_body_size has invalid syntax '$val'. Manual fix required."
            manual_intervention_required=1
            continue
        fi

        has_valid_size=1

    done < <(nginx -T 2>/dev/null | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*client_max_body_size[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*client_max_body_size[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print val
        }
    ')

    # Abort if unsafe
    if [[ "$manual_intervention_required" -eq 1 ]]; then
        return 1
    fi

    # Already valid → no action
    if [[ "$has_valid_size" -eq 1 ]]; then
        return 0
    fi

    [[ -f "$main_config" ]] || return 1

    local backup_file="${main_config}.bak.$(date +%s)"
    cp -p "$main_config" "$backup_file" || return 1

    awk '
        /^[[:space:]]*#/ { print; next }

        /^[[:space:]]*http[[:space:]]*\{/ && !done {
            print
            print "    client_max_body_size 100K;"
            done=1
            next
        }

        { print }
    ' "$main_config" > "${main_config}.tmp" && mv "${main_config}.tmp" "$main_config"

    if ! nginx -t >/dev/null 2>&1; then
        mv "$backup_file" "$main_config"
        return 1
    fi

    rm -f "$backup_file"
    nginx -s reload >/dev/null 2>&1

    return 0
}