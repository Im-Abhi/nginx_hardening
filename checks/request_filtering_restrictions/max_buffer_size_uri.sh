#!/usr/bin/env bash

# CIS 5.2.3 – Ensure the maximum buffer size for URIs is defined
# SAFE MODE: No override of existing explicit directives

check_large_client_header_buffers() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local errors=""
    local warnings=""
    local has_valid_directive=0

    while read -r file line val; do

        local val_clean="${val,,}"
        val_clean=$(echo "$val_clean" | awk '{print $1, $2}')

        has_valid_directive=1

        if [[ "$val_clean" != "2 1k" ]]; then
            warnings+="  - [WARNING] large_client_header_buffers in $file (line $line) is '$val' (CIS recommends '2 1k').\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*large_client_header_buffers[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*large_client_header_buffers[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, val
        }
    ')

    # Missing directive → FAIL
    if [[ "$has_valid_directive" -eq 0 ]]; then
        errors+="  - large_client_header_buffers directive is missing entirely (NGINX default is 4 8k).\n"
    fi

    # FAIL only on real errors
    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Ensure buffers are restricted to mitigate volumetric DoS attacks.\n"
        errors+="  - WARNING: If your app uses large cookies/OAuth, '2 1k' may cause 400/414 errors.\n"
        errors+="  - Example:\n"
        errors+="      large_client_header_buffers 2 1k;"
        echo -e "${errors%\\n}"
        return 1
    fi

    # PASS (silent, warnings suppressed per framework)
    return 0
}

remediate_large_client_header_buffers() {

    command -v nginx >/dev/null 2>&1 || return 1

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local main_config="/etc/nginx/nginx.conf"
    local has_valid_directive=0
    local manual_intervention_required=0

    while read -r val; do

        local val_clean="${val,,}"
        val_clean=$(echo "$val_clean" | awk '{print $1, $2}')

        has_valid_directive=1

        if [[ "$val_clean" != "2 1k" ]]; then
            manual_intervention_required=1
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*large_client_header_buffers[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*large_client_header_buffers[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print val
        }
    ')

    # Abort if custom value exists
    if [[ "$manual_intervention_required" -eq 1 ]]; then
        echo "[WARNING] large_client_header_buffers is set to a custom value. Manual review required."
        return 1
    fi

    # Already exists → do nothing
    if [[ "$has_valid_directive" -eq 1 ]]; then
        return 0
    fi

    [[ -f "$main_config" ]] || return 1

    local backup_file="${main_config}.bak.$(date +%s)"
    cp -p "$main_config" "$backup_file" || return 1

    awk '
        /^[[:space:]]*#/ { print; next }

        /^[[:space:]]*http[[:space:]]*\{/ && !done {
            print
            print "    large_client_header_buffers 2 1k;"
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