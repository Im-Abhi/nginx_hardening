#!/usr/bin/env bash

# CIS 5.2.1 – Ensure timeout values for reading the client header and body are set correctly
# Automation Level: Automated (SAFE MODE: no override of existing directives)

check_client_timeouts() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local errors=""
    local has_body_timeout=0
    local has_header_timeout=0

    while read -r file line type val; do

        local val_clean="${val%s}"

        if [[ "$type" == "client_body_timeout" ]]; then
            has_body_timeout=1
            if ! [[ "$val_clean" =~ ^[0-9]+$ ]] || [[ "$val_clean" -ne 10 ]]; then
                errors+="  - $type in $file (line $line) is set to $val (Expected: 10).\n"
            fi

        elif [[ "$type" == "client_header_timeout" ]]; then
            has_header_timeout=1
            if ! [[ "$val_clean" =~ ^[0-9]+$ ]] || [[ "$val_clean" -ne 10 ]]; then
                errors+="  - $type in $file (line $line) is set to $val (Expected: 10).\n"
            fi
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*(client_body_timeout|client_header_timeout)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(client_body_timeout|client_header_timeout)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, type, val
        }
    ')

    if [[ "$has_body_timeout" -eq 0 ]]; then
        errors+="  - 'client_body_timeout' directive is missing entirely (NGINX default: 60s).\n"
    fi

    if [[ "$has_header_timeout" -eq 0 ]]; then
        errors+="  - 'client_header_timeout' directive is missing entirely (NGINX default: 60s).\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Add the following directives to your 'http' block:\n"
        errors+="      client_body_timeout   10;\n"
        errors+="      client_header_timeout 10;"
        
        echo -e "${errors%\\n}"
        return 1
    fi
}

remediate_client_timeouts() {

    command -v nginx >/dev/null 2>&1 || return 1

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local has_body_timeout=0
    local has_header_timeout=0

    while read -r type; do
        [[ "$type" == "client_body_timeout" ]] && has_body_timeout=1
        [[ "$type" == "client_header_timeout" ]] && has_header_timeout=1
    done < <(nginx -T 2>/dev/null | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*(client_body_timeout|client_header_timeout)[[:space:]]+/ {
            print $1
        }
    ')

    # Nothing to do
    if [[ "$has_body_timeout" -eq 1 && "$has_header_timeout" -eq 1 ]]; then
        echo "[INFO] Timeout directives already exist. No changes applied."
        return 0
    fi

    [[ -f "$main_config" ]] || {
        echo "Main nginx config not found"
        return 1
    }

    # Backup
    local backup_file="${main_config}.bak.$(date +%s)"
    cp -p "$main_config" "$backup_file" || return 1
    backups+=("$main_config:$backup_file")

    echo "[INFO] Injecting missing timeout directives into http block"

    awk -v b_missing="$((1 - has_body_timeout))" -v h_missing="$((1 - has_header_timeout))" '
        /^[[:space:]]*#/ { print; next }

        /^[[:space:]]*http[[:space:]]*\{/ && !done {
            print
            if (b_missing == 1) print "    client_body_timeout 10;"
            if (h_missing == 1) print "    client_header_timeout 10;"
            done=1
            next
        }

        { print }
    ' "$main_config" > "${main_config}.tmp" && mv "${main_config}.tmp" "$main_config"

    # Validate
    if ! nginx -t >/dev/null 2>&1; then
        echo "[ERROR] nginx config test failed. Rolling back."
        mv "$backup_file" "$main_config"
        return 1
    fi

    # Cleanup
    rm -f "$backup_file"

    nginx -s reload >/dev/null 2>&1
    echo "[SUCCESS] Timeout directives applied safely"

    return 0
}