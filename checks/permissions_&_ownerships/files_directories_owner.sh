#!/usr/bin/env bash

# CIS 2.3.1 – Ensure NGINX directories and files are owned by root
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

check_files_directories_owner() {
    local conf_dir
    conf_dir=$(_get_nginx_conf_dir)

    if [[ ! -d "$conf_dir" ]]; then
        manual "2.3.1 ownership check failed (directory '$conf_dir' not found)"
        return
    fi

    local non_compliant
    non_compliant=$(find "$conf_dir" -xdev \
        \( ! -user root -o ! -group root \) \
        -printf "  - %p\n" 2>/dev/null)

    if [[ -z "$non_compliant" ]]; then
        pass "2.3.1 all files and directories in '$conf_dir' are owned by root:root"
    else
        handle_failure \
        "2.3.1 found files/directories not owned by root:root:\n$non_compliant" \
        remediate_files_directories_owner
    fi
}

remediate_files_directories_owner() {
    local conf_dir
    conf_dir=$(_get_nginx_conf_dir)

    if [[ ! -d "$conf_dir" ]]; then
        return 1
    fi

    # Only fix non-compliant entries
    if ! find "$conf_dir" -xdev \
        \( ! -user root -o ! -group root \) \
        -exec chown root:root {} + \
        >/dev/null 2>&1; then
        return 1
    fi

    return 0
}
