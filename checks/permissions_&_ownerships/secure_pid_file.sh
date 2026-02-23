#!/bin/bash

# CIS 2.3.3 – Ensure the NGINX PID file is secured
# Verifies:
#   - /var/run/nginx.pid is owned by root:root
#   - Permissions are 644 or more restrictive
# Automation Level: Automated (safe ownership and permission correction)

check_nginx_pid_file() {

    local pid_file="/var/run/nginx.pid"

    if [[ ! -e "$pid_file" ]]; then
        fail "NGINX PID file not found"
        return
    fi

    local owner perm
    owner=$(stat -L -c "%U:%G" "$pid_file" 2>/dev/null)
    perm=$(stat -L -c "%a" "$pid_file" 2>/dev/null)

    if [[ "$owner" == "root:root" && "$perm" -le 644 ]]; then
        pass "NGINX PID file is properly secured"
        return
    fi

    remediate_nginx_pid_file
}

remediate_nginx_pid_file() {

    local pid_file="/var/run/nginx.pid"

    if [[ ! -e "$pid_file" ]]; then
        fail "NGINX PID file not found"
        return
    fi

    chown root:root "$pid_file" 2>/dev/null
    chmod u-x,go-wx "$pid_file" 2>/dev/null

    local owner perm
    owner=$(stat -L -c "%U:%G" "$pid_file" 2>/dev/null)
    perm=$(stat -L -c "%a" "$pid_file" 2>/dev/null)

    if [[ "$owner" == "root:root" && "$perm" -le 644 ]]; then
        pass "NGINX PID file ownership and permissions corrected"
    else
        fail "PID file remediation failed"
    fi
}