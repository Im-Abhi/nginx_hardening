#!/usr/bin/env bash

# CIS 5.3.3 – Ensure that Content Security Policy (CSP) is enabled and configured properly
# Automation Level: Manual (Auto-remediation disabled to prevent application breakage)

check_content_security_policy() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local findings=""
    local has_csp=0

    while read -r file line val; do
        has_csp=1

        local val_upper="${val^^}"
        val_upper="$(echo "$val_upper" | awk '{$1=$1; print}')"
        local policy=""

        if ! [[ "$val_upper" =~ (^|[[:space:]])ALWAYS($|[[:space:]]) ]]; then
            findings+="  - [ERROR] Content-Security-Policy in $file (line $line) is missing the 'always' parameter.\n"
        fi

        policy="${val_upper% ALWAYS}"
        policy="${policy#ALWAYS }"

        if [[ -z "$policy" ]] || ! [[ "$policy" =~ [A-Z] ]]; then
            findings+="  - [ERROR] Content-Security-Policy in $file (line $line) appears empty or malformed: '$val'\n"
        fi

        if [[ "$policy" =~ UNSAFE-INLINE ]]; then
            findings+="  - [WARNING] Content-Security-Policy in $file (line $line) uses 'unsafe-inline', weakening XSS protection.\n"
        fi

        if [[ "$policy" =~ UNSAFE-EVAL ]]; then
            findings+="  - [WARNING] Content-Security-Policy in $file (line $line) uses 'unsafe-eval', weakening script execution protections.\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+/ {
            line_val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+/, "", line_val)
            sub(/;[[:space:]]*$/, "", line_val)

            # Match Content-Security-Policy (case-insensitive, optional quotes)
            if (match(line_val, /^["\047]?[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Ss][Ee][Cc][Uu][Rr][Ii][Tt][Yy]-[Pp][Oo][Ll][Ii][Cc][Yy]["\047]?[[:space:]]+/)) {
                val = substr(line_val, RLENGTH + 1)
                gsub(/["\047]/, "", val)
                print file, line, val
            }
        }
    ')

    if [[ "$has_csp" -eq 0 ]]; then
        findings+="  - [ERROR] 'Content-Security-Policy' header is not configured.\n"
    fi

    if [[ -n "$findings" ]]; then
        findings+="\n  Remediation Guidance:\n"
        findings+="  - Configure a Content-Security-Policy (CSP) to mitigate Cross-Site Scripting (XSS).\n"
        findings+="  - CSP policies are highly application-specific. Work with developers to map required origins.\n"
        findings+="  - Avoid using 'unsafe-inline' and 'unsafe-eval' unless absolutely necessary.\n"
        findings+="  - Example baseline directive (Add to 'http' or 'server' block):\n"
        findings+="      add_header Content-Security-Policy \"default-src 'self'\" always;"

        echo -e "${findings%\\n}"
        return 1
    fi

    return 0
}

remediate_content_security_policy() {

    # Blindly injecting a strict CSP (e.g., "default-src 'self'") can break applications
    # relying on CDNs, external APIs, inline scripts, or external fonts.
    return 1
}