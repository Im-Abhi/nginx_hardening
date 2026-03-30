#!/usr/bin/env bash

# CIS 2.3.3 – Ensure the NGINX PID file is secured
# Automation Level: Automated

_get_nginx_pid_file() {
    local pid_path=""

    # 1. Try runtime configuration (only if config is valid)
    if nginx -t >/dev/null 2>&1; then
        pid_path="$(nginx -T 2>/dev/null \
            | grep -Evi '^[[:space:]]*#' \
            | awk '/^[[:space:]]*pid[[:space:]]+/{sub(/;/,"",$2); print $2; exit}')"
    fi

    # 2. Fallback to compile-time configuration
    if [[ -z "$pid_path" ]]; then
        pid_path="$(nginx -V 2>&1 | grep -o -- '--pid-path=[^ ]*' | cut -d= -f2)"
    fi

    # 3. Final fallback
    echo "${pid_path:-/var/run/nginx.pid}"
}

check_nginx_pid_file() {
    local pid_file
    local non_compliant
    local owner perm

    pid_file="$(_get_nginx_pid_file)"

    if [[ ! -e "$pid_file" ]]; then
        echo "nginx PID file not found ($pid_file)"
        return 1
    fi

    # -L checks the target if it's a symlink
    # -perm /0133 catches user execute, group/other write/execute
    non_compliant="$(find -L "$pid_file" -maxdepth 0 \
        \( ! -user root -o ! -group root -o -perm /0133 \) 2>/dev/null)"

    if [[ -z "$non_compliant" ]]; then
        return 0
    fi

    owner="$(stat -L -c "%U:%G" "$pid_file" 2>/dev/null || echo "unknown")"
    perm="$(stat -L -c "%a" "$pid_file" 2>/dev/null || echo "unknown")"

    echo "nginx PID file '$pid_file' has insecure ownership or permissions (owner: $owner, mode: $perm)"
    return 1
}

remediate_nginx_pid_file() {
    local pid_file
    pid_file="$(_get_nginx_pid_file)"

    if [[ ! -e "$pid_file" ]]; then
        return 1
    fi

    # Correct ownership
    chown root:root "$pid_file" >/dev/null 2>&1 || return 1

    # Ensure max mode <= 644
    chmod u-x,go-wx "$pid_file" >/dev/null 2>&1 || return 1

    return 0
}