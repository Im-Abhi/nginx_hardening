#!/bin/bash

# CIS 2.4.2 – Ensure requests for unknown host names are rejected
# Verifies:
#   - Invalid Host header returns 4xx response
#   - Every server block explicitly defines server_name
# Automation Level: Automated (safe catch-all insertion if needed)

check_unknown_host_rejection() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local status
    status=$(curl -k -s -o /dev/null -w "%{http_code}" \
        https://127.0.0.1 \
        -H "Host: invalid.host.com")

    local missing_server_name=0

    nginx -T 2>/dev/null | awk '
    BEGIN { in_server=0; depth=0; has_name=0 }
    /^[[:space:]]*#/ { next }

    /^[[:space:]]*server[[:space:]]*\{/ {
        in_server=1; depth=1; has_name=0; next
    }

    in_server {
        if ($0 ~ /\{/) depth++
        if ($0 ~ /\}/) depth--

        if (depth == 1 && $0 ~ /^[[:space:]]*server_name[[:space:]]+/)
            has_name=1

        if (depth == 0) {
            if (!has_name) print "MISSING"
            in_server=0
        }
    }
    ' | grep -q MISSING && missing_server_name=1

    if [[ "$status" =~ ^4[0-9][0-9]$ && "$missing_server_name" -eq 0 ]]; then
        pass "Unknown host requests rejected and server_name explicitly defined"
        return
    fi

    remediate_unknown_host_rejection
}

remediate_unknown_host_rejection() {

    local target_file="/etc/nginx/conf.d/00-cis-default-catchall.conf"
    local backup_file="${target_file}.bak.$(date +%s)"

    if [[ -f "$target_file" ]]; then
        cp "$target_file" "$backup_file" || { fail "backup failed"; return; }
    fi

    cat > "$target_file" <<EOF
server {
    return 404;
}
EOF

    if ! nginx -t >/dev/null 2>&1; then
        [[ -f "$backup_file" ]] && mv "$backup_file" "$target_file"
        fail "nginx configuration invalid after remediation"
        return
    fi

    nginx -s reload >/dev/null 2>&1

    local verify
    verify=$(curl -k -s -o /dev/null -w "%{http_code}" \
        https://127.0.0.1 \
        -H "Host: invalid.host.com")

    if [[ "$verify" =~ ^4[0-9][0-9]$ ]]; then
        rm -f "$backup_file"
        pass "Unknown host rejection configured"
    else
        [[ -f "$backup_file" ]] && mv "$backup_file" "$target_file"
        nginx -t >/dev/null 2>&1 && nginx -s reload >/dev/null 2>&1
        fail "Unknown host rejection remediation failed"
    fi
}