#!/usr/bin/env bash

# CIS 4.1.1 - Ensure HTTP is redirected to HTTPS
# Automation Level: Manual

check_http_to_https_redirect() {
    local config
    local errors=""

    # -------- Prerequisite Check --------
    if ! command -v nginx >/dev/null 2>&1; then
        echo "  - nginx binary not found."
        return
    fi

    if ! config="$(nginx -T 2>/dev/null)"; then
        echo "  - Nginx configuration dump failed."
        return
    fi

    # -------- Remove commented lines --------
    local clean_config
    clean_config="$(grep -Evi '^[[:space:]]*#' <<< "$config")"

    # -------- Detect HTTP listeners --------
    if grep -Eqi '^[[:space:]]*listen[[:space:]]+[^;]*(^|[[:space:]:])80([[:space:]]|;)' <<< "$clean_config"; then

        # -------- Check for HTTPS redirect --------
        if ! grep -Eqi '^[[:space:]]*return[[:space:]]+301[[:space:]]+https://' <<< "$clean_config"; then
            errors+="  - HTTP (port 80) listener found, but no explicit 'return 301 https://' redirect detected.\n"
        fi
    fi

    # -------- Output Reporting --------
    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit your web server configuration to redirect all unencrypted listening ports (e.g., port 80) to HTTPS.\n"
        errors+="  - Example configuration:\n"
        errors+="      server {\n"
        errors+="          listen 80;\n"
        errors+="          server_name example.com;\n"
        errors+="          return 301 https://\$host\$request_uri;\n"
        errors+="      }\n"

        echo -e "${errors%\\n}"
    fi
}

remediate_http_to_https_redirect() {
    return 1
}