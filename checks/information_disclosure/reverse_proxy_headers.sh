#!/usr/bin/env bash

# CIS 2.5.4 – Ensure the NGINX reverse proxy does not enable information disclosure
# Automation Level: Automated

check_proxy_hide_headers() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local config

    config="$(nginx -T 2>/dev/null)"

    # Check for X-Powered-By suppression (fixed regex anchor)
    if ! grep -Eqi '^[[:space:]]*proxy_hide_header[[:space:]]+X-Powered-By[[:space:]]*;' <<< "$config"; then
        errors+="  - proxy_hide_header for 'X-Powered-By' is missing\n"
    fi

    # Check for Server suppression (fixed regex anchor)
    if ! grep -Eqi '^[[:space:]]*proxy_hide_header[[:space:]]+Server[[:space:]]*;' <<< "$config"; then
        errors+="  - proxy_hide_header for 'Server' is missing\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit your NGINX configuration and add the following to your 'http', 'server', or 'location' blocks:\n"
        errors+="      proxy_hide_header X-Powered-By;\n"
        errors+="      proxy_hide_header Server;"
        echo -e "${errors%\\n}"
    fi
}


remediate_proxy_hide_headers() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local config
    local has_xpb=0
    local has_server=0

    config="$(nginx -T 2>/dev/null)"

    if grep -Eqi '^[[:space:]]*proxy_hide_header[[:space:]]+X-Powered-By[[:space:]]*;' <<< "$config"; then
        has_xpb=1
    fi

    if grep -Eqi '^[[:space:]]*proxy_hide_header[[:space:]]+Server[[:space:]]*;' <<< "$config"; then
        has_server=1
    fi

    if [[ "$has_xpb" -eq 1 && "$has_server" -eq 1 ]]; then
        return 0
    fi

    [[ -f "$main_config" ]] || return 1

    local backup_file="${main_config}.bak.$(date +%s)"
    cp "$main_config" "$backup_file" || return 1

    if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then

        # Safely split multi-line injections for cross-platform compatibility
        if [[ "$has_xpb" -eq 0 && "$has_server" -eq 0 ]]; then
            sed -i '/http[[:space:]]*{/a \    proxy_hide_header X-Powered-By;' "$main_config"
            sed -i '/http[[:space:]]*{/a \    proxy_hide_header Server;' "$main_config"

        elif [[ "$has_xpb" -eq 0 ]]; then
            sed -i '/http[[:space:]]*{/a \    proxy_hide_header X-Powered-By;' "$main_config"

        elif [[ "$has_server" -eq 0 ]]; then
            sed -i '/http[[:space:]]*{/a \    proxy_hide_header Server;' "$main_config"
        fi

    else
        return 1
    fi

    if ! nginx -t >/dev/null 2>&1; then
        mv "$backup_file" "$main_config"
        return 1
    fi

    rm -f "$backup_file"

    nginx -s reload >/dev/null 2>&1

    return 0
}