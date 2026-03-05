#!/usr/bin/env bash

# CIS 2.4.2 – Ensure requests for unknown host names are rejected
# Verifies:
#   - Invalid Host header returns 4xx response
#   - Every server block explicitly defines server_name
# Automation Level: Automated (safe HTTP catch-all insertion) / Manual for server_names

check_unknown_host_rejection() {

    local errors=""

    # -------- Prerequisite --------
    if ! nginx -t >/dev/null 2>&1; then
        manual "2.4.2 nginx configuration invalid"
        return
    fi

    # -------- 1. Active Rejection Test --------
    local status

    status=$(curl -k -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 2 --max-time 3 \
        https://127.0.0.1 \
        -H "Host: invalid.host.local" 2>/dev/null)

    if [[ "$status" == "000" || -z "$status" ]]; then
        status=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout 2 --max-time 3 \
            http://127.0.0.1 \
            -H "Host: invalid.host.local" 2>/dev/null)
    fi

    if [[ ! "$status" =~ ^4[0-9][0-9]$ ]]; then
        errors+="  - Unknown host requests are not rejected (HTTP Status returned: ${status:-None})\n"
    fi

    # -------- 2. Detect missing server_name directives --------
    if nginx -T 2>/dev/null | awk '
        BEGIN { in_server=0; depth=0; has_name=0 }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*server[[:space:]]*\{/ { in_server=1; depth=1; has_name=0; next }
        in_server {
            if ($0 ~ /\{/) depth++
            if ($0 ~ /\}/) depth--
            if (depth == 1 && $0 ~ /^[[:space:]]*server_name[[:space:]]+/) has_name=1
            if (depth == 0) {
                if (!has_name) print "MISSING"
                in_server=0
            }
        }
    ' | grep -q "MISSING"; then
        errors+="  - One or more server{} blocks are missing a 'server_name' directive\n"
    fi

    # -------- Final Reporting --------
    if [[ -z "$errors" ]]; then
        pass "2.4.2 Unknown host requests rejected and server_names explicitly defined"
    else
        handle_failure \
"2.4.2 Unknown host rejection checks failed:
${errors%\\n}

Remediation Guidance:
  - Deploy a default catch-all server block:

        server {
            listen 80 default_server;
            server_name _;
            return 444;
        }

  - Ensure every real server block explicitly defines a 'server_name'.
" \
        remediate_unknown_host_rejection
    fi
}


remediate_unknown_host_rejection() {

    local conf_d_dir="/etc/nginx/conf.d"
    local target_file="$conf_d_dir/00-cis-default-catchall.conf"
    local backup_file="${target_file}.bak.$(date +%s)"
    local catchall_fixed=0

    [[ -d "$conf_d_dir" ]] || return 1

    # Detect default server
    if ! nginx -T 2>/dev/null | grep -E "listen[[:space:]]+80[[:space:]]+default_server" >/dev/null; then

        if [[ -f "$target_file" ]]; then
            cp "$target_file" "$backup_file" || return 1
        fi

        cat > "$target_file" <<EOF
# CIS 2.4.2 Catch-all server to reject unknown Host headers
server {
    listen 80 default_server;
    server_name _;
    return 444;
}
EOF

        if nginx -t >/dev/null 2>&1; then
            nginx -s reload >/dev/null 2>&1
            catchall_fixed=1
        else
            [[ -f "$backup_file" ]] && mv "$backup_file" "$target_file" || rm -f "$target_file"
            return 1
        fi
    fi

    # Even if catch-all fixed, server_name issues remain manual
    return 1
}