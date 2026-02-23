#!/bin/bash

# CIS 2.3.1 – Ensure NGINX directories and files are owned by root
# Verifies:
#   - All files and directories under /etc/nginx are owned by root:root
# Automation Level: Automated (safe recursive ownership correction)
# Remediation Example:
#   chown -R root:root /etc/nginx

check_nginx_ownership() {

    if [[ ! -d /etc/nginx ]]; then
        fail "/etc/nginx directory not found"
        return
    fi

    local non_compliant
    non_compliant=$(find /etc/nginx \( ! -user root -o ! -group root \) -print -quit 2>/dev/null)

    if [[ -z "$non_compliant" ]]; then
        pass "All nginx directories and files owned by root"
        return
    fi

    remediate_nginx_ownership
}

remediate_nginx_ownership() {

    if ! chown -R root:root /etc/nginx 2>/dev/null; then
        fail "Failed to set ownership to root:root"
        return
    fi

    local verify
    verify=$(find /etc/nginx \( ! -user root -o ! -group root \) -print -quit 2>/dev/null)

    if [[ -z "$verify" ]]; then
        pass "Ownership corrected to root:root"
    else
        fail "Ownership remediation failed"
    fi
}