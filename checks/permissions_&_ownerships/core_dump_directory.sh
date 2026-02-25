#!/bin/bash

# CIS 2.3.4 – Ensure the core dump directory is secured
# Verifies:
#   - working_directory directive (if present) is compliant
# Manual Control:
#   - Displays findings only if non-compliant
#   - No automatic remediation

check_core_dump_directory() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local config working_dir nginx_group
    local non_compliant=0

    config="$(nginx -T 2>/dev/null)"

    working_dir=$(echo "$config" | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*working_directory[[:space:]]+/ {
            gsub(";", "", $2)
            print $2
            exit
        }
    ')

    if [[ -z "$working_dir" ]]; then
        pass "working_directory directive not configured"
        return
    fi

    nginx_group=$(awk -F: '/^nginx:/{print $1}' /etc/group)

    [[ -z "$nginx_group" ]] && nginx_group="nginx"

    if [[ ! -d "$working_dir" ]]; then
        printf "Directory not found: %s\n" "$working_dir"
        fail "Core dump directory non-compliant"
        return
    fi

    local owner group perm
    owner=$(stat -c "%U" "$working_dir" 2>/dev/null)
    group=$(stat -c "%G" "$working_dir" 2>/dev/null)
    perm=$(stat -c "%a" "$working_dir" 2>/dev/null)

    if [[ "$owner" != "root" ]]; then
        printf "Owner mismatch: %s (expected root)\n" "$owner"
        non_compliant=1
    fi

    if [[ "$group" != "$nginx_group" ]]; then
        printf "Group mismatch: %s (expected %s)\n" "$group" "$nginx_group"
        non_compliant=1
    fi

    if (( perm % 10 != 0 )); then
        printf "Other permissions not restricted: %s\n" "$perm"
        non_compliant=1
    fi

    if [[ "$working_dir" == /usr/share/nginx/html* ]]; then
        printf "Directory within web document root: %s\n" "$working_dir"
        non_compliant=1
    fi

    if [[ "$non_compliant" -eq 0 ]]; then
        pass "Core dump directory is compliant"
    else
        fail "Core dump directory non-compliant"
    fi
}