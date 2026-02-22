#!/bin/bash

# CIS 2.4.3 – Ensure keepalive_timeout is 10 seconds or less, but not 0
# Verifies:
#   - keepalive_timeout directive exists
#   - Value is > 0 and <= 10
# Automation Level: Automated (safe update if non-compliant)
# Remediation Example:
#   keepalive_timeout 10;

check_keepalive_timeout() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local config value compliant=0 found=0

    config="$(nginx -T 2>/dev/null)"

    while IFS= read -r line; do

        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^[[:space:]]*keepalive_timeout[[:space:]]+([0-9]+) ]]; then
            found=1
            value="${BASH_REMATCH[1]}"

            if [[ "$value" -gt 0 && "$value" -le 10 ]]; then
                compliant=1
            fi
        fi

    done < <(echo "$config")

    if [[ "$found" -eq 1 && "$compliant" -eq 1 ]]; then
        pass "keepalive_timeout is properly configured"
        return
    fi

    remediate_keepalive_timeout
}

remediate_keepalive_timeout() {

    local target_file="/etc/nginx/nginx.conf"
    local backup_file="${target_file}.bak.$(date +%s)"

    if [[ ! -f "$target_file" ]]; then
        fail "nginx.conf not found"
        return
    fi

    cp "$target_file" "$backup_file" || { fail "backup failed"; return; }

    if grep -Eq '^[[:space:]]*keepalive_timeout' "$target_file"; then
        sed -i -E 's/^[[:space:]]*keepalive_timeout[[:space:]]+[0-9]+.*/keepalive_timeout 10;/' "$target_file"
    else
        sed -i '/http\s*{/a \    keepalive_timeout 10;' "$target_file"
    fi

    if ! nginx -t >/dev/null 2>&1; then
        mv "$backup_file" "$target_file"
        fail "nginx configuration invalid after remediation"
        return
    fi

    nginx -s reload >/dev/null 2>&1
    rm -f "$backup_file"

    pass "keepalive_timeout remediated to 10 seconds"
}