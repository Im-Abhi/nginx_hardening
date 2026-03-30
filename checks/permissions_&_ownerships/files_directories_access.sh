#!/usr/bin/env bash

# CIS 2.3.2 – Ensure access to NGINX directories and files is restricted
# Automation Level: Automated

_get_nginx_conf_dir() {
    local conf_path
    conf_path="$(nginx -V 2>&1 \
        | grep -o -- '--conf-path=[^ ]*' \
        | cut -d= -f2)"

    if [[ -n "$conf_path" ]]; then
        dirname "$conf_path"
    else
        echo "/etc/nginx"
    fi
}

check_files_directories_access() {
    local conf_dir
    local non_compliant

    conf_dir="$(_get_nginx_conf_dir)"

    if [[ ! -d "$conf_dir" ]]; then
        echo "permissions check failed (directory '$conf_dir' not found)"
        return 1
    fi

    non_compliant="$(find "$conf_dir" -xdev \
        \( \
            \( -type d -perm /022 \) -o \
            \( -type f -perm /133 \) \
        \) \
        -printf "  - %p (perms: %m)\n" 2>/dev/null)"

    if [[ -z "$non_compliant" ]]; then
        return 0
    fi

    echo -e "found files/directories with incorrect permissions:\n$non_compliant"
    return 1
}

remediate_files_directories_access() {
    local conf_dir
    conf_dir="$(_get_nginx_conf_dir)"

    if [[ ! -d "$conf_dir" ]]; then
        return 1
    fi

    # Fix only non-compliant directories
    find "$conf_dir" -xdev \
        -type d -perm /022 \
        -exec chmod 755 {} + >/dev/null 2>&1 || return 1

    # Fix only non-compliant files
    find "$conf_dir" -xdev \
        -type f -perm /133 \
        -exec chmod 644 {} + >/dev/null 2>&1 || return 1

    return 0
}