#!/bin/bash

# CIS 3.3 – Ensure error logging is enabled and set to info level
# Verifies:
#   - error_log directive exists
#   - Not commented out
#   - Logging level is set to info
# Automation Level: Automated (safe update of nginx.conf only)
# Remediation Example:
#   error_log /var/log/nginx/error_log.log info;

check_error_logging() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local config compliant=0

    config="$(nginx -T 2>/dev/null)"

    # Fixed: Extracted the regex with the semicolon into a variable
    local re_error_info='^[[:space:]]*error_log[[:space:]]+[^;]+[[:space:]]+info[[:space:]]*;'

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ $re_error_info ]]; then
            compliant=1
            break
        fi
    done <<< "$config"

    if [[ "$compliant" -eq 1 ]]; then
        pass "Error logging enabled with info level"
        return
    fi

    remediate_error_logging
}

remediate_error_logging() {

    local target_file="/etc/nginx/nginx.conf"
    local backup_file="${target_file}.bak.$(date +%s%N)"

    if [[ ! -f "$target_file" ]]; then
        fail "nginx.conf not found"
        return
    fi

    cp "$target_file" "$backup_file" || { fail "backup failed"; return; }

    if grep -Eq '^[[:space:]]*error_log[[:space:]]+' "$target_file"; then
        sed -i -E \
        's|^[[:space:]]*error_log[[:space:]]+[^;]+;|error_log /var/log/nginx/error_log.log info;|' \
        "$target_file"
    else
        # Fixed: Standardized spaces in the sed append string
        sed -i '/http[[:space:]]*{/a \    error_log /var/log/nginx/error_log.log info;' \
        "$target_file"
    fi

    if ! nginx -t >/dev/null 2>&1; then
        mv "$backup_file" "$target_file"
        fail "nginx configuration invalid after remediation"
        return
    fi

    nginx -s reload >/dev/null 2>&1

    local verify
    verify="$(nginx -T 2>/dev/null)"

    if echo "$verify" | grep -Eq '^[[:space:]]*error_log[[:space:]]+[^;]+[[:space:]]+info[[:space:]]*;' ; then
        rm -f "$backup_file"
        pass "Error logging remediated to info level"
    else
        mv "$backup_file" "$target_file"
        nginx -t >/dev/null 2>&1 && nginx -s reload >/dev/null 2>&1
        fail "Error logging remediation failed"
    fi
}