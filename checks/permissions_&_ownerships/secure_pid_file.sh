#!/usr/bin/env bash

# CIS 2.3.3 – Ensure the NGINX PID file is secured
# Automation Level: Automated

_get_nginx_pid_file() {
    local pid_path=""

    # 1. Try runtime configuration (only if config is valid to avoid spamming errors)
    if nginx -t >/dev/null 2>&1; then
        pid_path=$(nginx -T 2>/dev/null \
            | grep -Evi '^[[:space:]]*#' \
            | awk '/^[[:space:]]*pid[[:space:]]+/{sub(/;/,"",$2); print $2; exit}')
    fi

    # 2. Fallback to compile-time configuration
    if [[ -z "$pid_path" ]]; then
        pid_path=$(nginx -V 2>&1 | grep -o -- '--pid-path=[^ ]*' | cut -d= -f2)
    fi

    # 3. Ultimate fallback using bash parameter expansion (DRY)
    echo "${pid_path:-/var/run/nginx.pid}"
}

check_nginx_pid_file() {
    local pid_file
    pid_file=$(_get_nginx_pid_file)

    if [[ ! -e "$pid_file" ]]; then
        manual "2.3.3 nginx PID file not found ($pid_file)"
        return
    fi

    # -------- Detection Logic --------
    # -L ensures we check the target if it's a symlink
    # -perm /0133 evaluates if user-execute, group-write/execute, or other-write/execute are set
    local non_compliant
    non_compliant=$(find -L "$pid_file" -maxdepth 0 \
        \( ! -user root -o ! -group root -o -perm /0133 \) 2>/dev/null)

    if [[ -z "$non_compliant" ]]; then
        pass "2.3.3 nginx PID file '$pid_file' is securely configured"
    else
        # -------- Failure Handling --------
        # Collect ownership & permissions ONLY for the failure message context
        local owner perm
        owner=$(stat -L -c "%U:%G" "$pid_file" 2>/dev/null || echo "unknown")
        perm=$(stat -L -c "%a" "$pid_file" 2>/dev/null || echo "unknown")

        handle_failure \
            "2.3.3 nginx PID file '$pid_file' has insecure ownership or permissions (owner: $owner, mode: $perm)" \
            remediate_nginx_pid_file
    fi
}

remediate_nginx_pid_file() {
    local pid_file
    pid_file=$(_get_nginx_pid_file)

    if [[ ! -e "$pid_file" ]]; then
        return 1
    fi

    # Correct ownership
    chown root:root "$pid_file" >/dev/null 2>&1 || return 1

    # Remove execute from user, and write/execute from group/others (ensures <= 644)
    chmod u-x,go-wx "$pid_file" >/dev/null 2>&1 || return 1

    return 0
}