#!/bin/bash

# CIS 2.3.2 – Ensure access to NGINX directories and files is restricted
# Verifies:
#   - Directories under /etc/nginx are 755 or more restrictive
#   - Files under /etc/nginx are 660 or more restrictive
# Automation Level: Automated (safe permission tightening)

check_nginx_permissions() {

    if [[ ! -d /etc/nginx ]]; then
        fail "/etc/nginx directory not found"
        return
    fi

    local dir_violation file_violation

    dir_violation=$(find /etc/nginx -type d -perm /022 -print -quit 2>/dev/null)

    file_violation=$(find /etc/nginx -type f \( -perm /001 -o -perm /002 -o -perm /004 \) -print -quit 2>/dev/null)

    if [[ -z "$dir_violation" && -z "$file_violation" ]]; then
        pass "NGINX directory and file permissions are restricted"
        return
    fi

    remediate_nginx_permissions
}

remediate_nginx_permissions() {

    find /etc/nginx -type d -exec chmod go-w {} + 2>/dev/null
    find /etc/nginx -type f -exec chmod ug-x,o-rwx {} + 2>/dev/null

    local verify_dir verify_file

    verify_dir=$(find /etc/nginx -type d -perm /022 -print -quit 2>/dev/null)

    verify_file=$(find /etc/nginx -type f \( -perm /001 -o -perm /002 -o -perm /004 \) -print -quit 2>/dev/null)

    if [[ -z "$verify_dir" && -z "$verify_file" ]]; then
        pass "NGINX permissions corrected"
    else
        fail "Permission remediation failed"
    fi
}