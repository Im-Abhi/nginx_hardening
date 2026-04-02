#!/usr/bin/env bash

# CIS 2.4.2 – Ensure requests for unknown host names are rejected
# Automation Level: Automated (with partial remediation)

check_unknown_host_rejection() {
    local findings=""
    local status=""
    local config_dump=""

    # -------- Prerequisite --------
    if ! nginx -t >/dev/null 2>&1; then
        echo "nginx configuration invalid"
        return 1
    fi

    if ! config_dump="$(nginx -T 2>/dev/null)"; then
        echo "nginx configuration dump failed"
        return 1
    fi

    # -------- 1. Active Rejection Test --------
    status="$(curl -k -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 2 --max-time 3 \
        https://127.0.0.1 \
        -H "Host: invalid.host.com" 2>/dev/null)"

    if [[ "$status" == "000" || -z "$status" ]]; then
        status="$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout 2 --max-time 3 \
            http://127.0.0.1 \
            -H "Host: invalid.host.com" 2>/dev/null)"
    fi

    # CIS explicitly expects 400-series
    if [[ ! "$status" =~ ^4[0-9][0-9]$ ]]; then
        findings+="  - Unknown host requests are not rejected with a 4xx response (HTTP status returned: ${status:-None})"$'\n'
    fi

    # -------- 2. Detect missing server_name directives --------
    if echo "$config_dump" | awk '
        BEGIN { in_server=0; depth=0; has_name=0 }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*server[[:space:]]*\{/ {
            in_server=1
            depth=1
            has_name=0
            next
        }

        in_server {
            opens = gsub(/\{/, "{")
            closes = gsub(/\}/, "}")

            if (depth == 1 && $0 ~ /^[[:space:]]*server_name[[:space:]]+/) {
                has_name=1
            }

            depth += opens
            depth -= closes

            if (depth <= 0) {
                if (!has_name) print "MISSING"
                in_server=0
                depth=0
            }
        }
    ' | grep -q '^MISSING$'; then
        findings+="  - One or more server{} blocks are missing a 'server_name' directive"$'\n'
    fi

    # -------- Final Reporting --------
    if [[ -z "$findings" ]]; then
        return 0
    fi

    echo -e "MANUAL: unknown host rejection checks failed:\n${findings%$'\n'}\n\
\nRemediation Guidance:\n\
  - Ensure your first/default server block rejects unmatched Host headers, for example:\n\n\
        server {\n\
            return 404;\n\
        }\n\n\
  - Ensure every real server block explicitly defines a 'server_name', for example:\n\n\
        server {\n\
            listen 443;\n\
            server_name example.com;\n\
            ...\n\
        }"

    return 1
}

remediate_unknown_host_rejection() {
    local conf_d_dir="/etc/nginx/conf.d"
    local target_file="$conf_d_dir/00-cis-default-catchall.conf"
    local backup_file="${target_file}.bak.$(date +%s%N)"

    [[ -d "$conf_d_dir" ]] || return 1

    # Only add a safe HTTP default catch-all if none exists
    if ! nginx -T 2>/dev/null | grep -Eq 'listen[[:space:]]+80([[:space:]].*)?\bdefault_server\b'; then
        if [[ -f "$target_file" ]]; then
            cp -- "$target_file" "$backup_file" || return 1
        fi

        cat > "$target_file" <<'EOF'
# CIS 2.4.2 Catch-all server to reject unknown Host headers
server {
    listen 80 default_server;
    server_name _;
    return 404;
}
EOF

        if ! nginx -t >/dev/null 2>&1; then
            if [[ -f "$backup_file" ]]; then
                mv -- "$backup_file" "$target_file"
            else
                rm -f -- "$target_file"
            fi
            return 1
        fi

        nginx -s reload >/dev/null 2>&1 || return 1
        [[ -f "$backup_file" ]] && rm -f -- "$backup_file"
    fi

    # Cannot safely auto-remediate missing server_name directives in existing application vhosts
    return 1
}