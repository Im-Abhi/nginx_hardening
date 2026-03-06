#!/usr/bin/env bash

# CIS 2.5.2 – Ensure default error and index.html pages do not reference NGINX
# Automation Level: Automated

check_default_pages_branding() {
    local errors=""
    local files_to_check=(
        "/usr/share/nginx/html/index.html"
        "/usr/share/nginx/html/50x.html"
        "/var/www/html/index.nginx-debian.html" # Common Debian/Ubuntu default
    )

    local file
    for file in "${files_to_check[@]}"; do
        if [[ -f "$file" ]] && grep -qi "nginx" "$file"; then
            errors+="  - Default branding found in $file\n"
        fi
    done

    # Output raw errors for the run_control engine
    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit the flagged HTML files.\n"
        errors+="  - Remove any lines that reference 'NGINX' or replace the text.\n"
        echo -e "${errors%\\n}"
    fi
}

remediate_default_pages_branding() {
    local files_to_check=(
        "/usr/share/nginx/html/index.html"
        "/usr/share/nginx/html/50x.html"
        "/var/www/html/index.nginx-debian.html"
    )
    local backups=()
    local modified=0

    local file
    for file in "${files_to_check[@]}"; do
        # Only process if the file exists and contains the string
        if [[ -f "$file" ]] && grep -qi "nginx" "$file"; then
            local backup_file="${file}.bak.$(date +%s)"
            cp "$file" "$backup_file" || return 1
            backups+=("$file:$backup_file")

            # CIS Remediation: "remove any lines that reference NGINX"
            # Using character classes for safe, cross-platform case-insensitivity
            sed -i '/[Nn][Gg][Ii][Nn][Xx]/d' "$file"
            modified=1
        fi
    done

    # If no files needed modification, return success
    if [[ "$modified" -eq 0 ]]; then
        return 0
    fi

    # Note: NGINX does not need to be reloaded for static HTML file changes.
    
    # Cleanup backups after successful modification
    local entry bak
    for entry in "${backups[@]}"; do
        bak="${entry##*:}"
        rm -f "$bak"
    done

    return 0
}