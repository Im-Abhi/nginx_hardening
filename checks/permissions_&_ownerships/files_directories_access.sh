#!/usr/bin/env bash

# CIS 2.3.2 – Ensure access to NGINX directories and files is restricted
# Automation Level: Automated

_get_nginx_conf_dir() {
    local conf_path
    conf_path=$(nginx -V 2>&1 \
        | grep -o -- '--conf-path=[^ ]*' \
        | cut -d= -f2)

    if [[ -n "$conf_path" ]]; then
        dirname "$conf_path"
    else
        echo "/etc/nginx"
    fi
}

check_files_directories_access() {
    local conf_dir
    conf_dir=$(_get_nginx_conf_dir)

    if [[ ! -d "$conf_dir" ]]; then
        manual "2.3.2 permissions check failed (directory '$conf_dir' not found)"
        return
    fi

    local non_compliant
    non_compliant=$(find "$conf_dir" -xdev \
        \( \
            \( -type d -perm /022 \) -o \
            \( -type f -perm /133 \) \
        \) \
        -printf "  - %p (perms: %m)\n" 2>/dev/null)

    if [[ -z "$non_compliant" ]]; then
        pass "2.3.2 all file and directory permissions in '$conf_dir' are compliant"
    else
        handle_failure \
        "2.3.2 found files/directories with incorrect permissions:\n$non_compliant" \
        remediate_files_directories_access
    fi
}

remediate_files_directories_access() {
    local conf_dir
    conf_dir=$(_get_nginx_conf_dir)

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
