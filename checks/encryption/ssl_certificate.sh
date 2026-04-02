#!/usr/bin/env bash

# CIS 4.1.2 - Ensure a trusted certificate and trust chain is installed
# Verifies:
#   - ssl_certificate and ssl_certificate_key directives exist
#   - The files referenced by the directives actually exist on disk
# Automation Level: Manual

check_ssl_certificate_configured() {
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

    local clean_config
    clean_config="$(grep -Evi '^[[:space:]]*#' <<< "$config")"

    # Using POSIX-compliant text processing instead of Perl-compatible \K regex
    local cert key
    cert=$(grep -Ei '^[[:space:]]*ssl_certificate[[:space:]]+' <<< "$clean_config" | head -n1 | awk '{print $2}' | tr -d ';')
    key=$(grep -Ei '^[[:space:]]*ssl_certificate_key[[:space:]]+' <<< "$clean_config" | head -n1 | awk '{print $2}' | tr -d ';')

    if [[ -z "$cert" || -z "$key" ]]; then
        errors+="  - SSL certificate and/or key directive missing in active NGINX configuration.\n"
    else
        # If directives exist, ensure the referenced files actually exist on disk
        if [[ ! -f "$cert" ]]; then
            errors+="  - SSL certificate file does not exist on disk: $cert\n"
        fi

        if [[ ! -f "$key" ]]; then
            errors+="  - SSL certificate key file does not exist on disk: $key\n"
        fi
    fi

    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Install a certificate and its signing certificate chain onto your web server.\n"
        errors+="  - Edit your encrypted listener to leverage the ssl_certificate and ssl_certificate_key directives.\n"
        errors+="  - Example configuration in the server block:\n"
        errors+="      server {\n"
        errors+="          listen 443 ssl http2;\n"
        errors+="          ssl_certificate /etc/nginx/cert.pem;\n"
        errors+="          ssl_certificate_key /etc/nginx/nginx.key;\n"
        errors+="          ...\n"
        errors+="      }\n"
        errors+="  - Ensure your certificate file (.pem or .crt) includes the full trust chain.\n"
        errors+="  - Reload nginx services to apply: sudo systemctl restart nginx"

        echo -e "${errors%\\n}"
    fi
}

remediate_ssl_certificate_configured() {
    # This control requires manual remediation.
    # Automatically generating or modifying SSL certificates and keys
    # is outside the scope of safe automated script actions.
    
    return 1
}