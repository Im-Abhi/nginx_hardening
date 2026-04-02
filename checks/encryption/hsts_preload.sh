#!/usr/bin/env bash

# CIS 4.1.11 – Ensure your domain is preloaded (HSTS Preload readiness)
# Automation Level: Manual

check_hsts_preload() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_hsts=0

    while read -r file line val; do
        has_hsts=1

        local val_lower="${val,,}"
        local max_age=""

        # Extract max-age
        if [[ "$val_lower" =~ max-age=([0-9]+) ]]; then
            max_age="${BASH_REMATCH[1]}"
        fi

        if [[ -z "$max_age" ]]; then
            errors+="  - HSTS in $file (line $line) missing 'max-age'.\n"
        elif [[ "$max_age" -lt 31536000 ]]; then
            errors+="  - HSTS in $file (line $line) max-age too low for preload (${max_age}s). Expected >= 31536000.\n"
        fi

        # includeSubDomains check
        if ! [[ "$val_lower" =~ (;|[[:space:]])includesubdomains(;|[[:space:]]|$) ]]; then
            errors+="  - HSTS in $file (line $line) missing 'includeSubDomains'.\n"
        fi

        # preload check
        if ! [[ "$val_lower" =~ (;|[[:space:]])preload(;|[[:space:]]|$) ]]; then
            errors+="  - HSTS in $file (line $line) missing 'preload'.\n"
        fi

        # NEW: always check (critical)
        if ! [[ "$val_lower" =~ (^|[[:space:]])always($|[[:space:]]) ]]; then
            errors+="  - HSTS in $file (line $line) missing 'always' parameter (required for consistent header delivery).\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, val
        }
    ')

    if [[ "$has_hsts" -eq 0 ]]; then
        errors+="  - HSTS header is missing entirely.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - WARNING: Preloading forces HTTPS on ALL subdomains.\n"
        errors+="  - Ensure ALL subdomains support HTTPS before enabling this.\n"
        errors+="  - Recommended configuration:\n"
        errors+="      add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains; preload\" always;\n"
        errors+="  - After verification, submit your domain to:\n"
        errors+="      https://hstspreload.org/"
        echo -e "${errors%\\n}"
    fi
}

remediate_hsts_preload() {

    # Intentionally manual control
    return 1
}