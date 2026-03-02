#!/usr/bin/env bash

# CIS 2.1.4 - Ensure the autoindex module is disabled
# Automation Level: Automated

check_autoindex() {
    local config failed=0

    if ! config="$(nginx -T 2>/dev/null)"; then
        fail "2.1.4 nginx configuration dump failed"
        return
    fi

    local re_autoindex_on='^[[:space:]]*autoindex[[:space:]]+[Oo][Nn][[:space:]]*;[[:space:]]*$'

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" =~ $re_autoindex_on ]]; then
            failed=1
            break
        fi
    done <<< "$config"

    if [[ "$failed" -eq 0 ]]; then
        pass "2.1.4 autoindex is disabled"
        return
    fi

    handle_failure "2.1.4 autoindex is enabled" remediate_autoindex
}

remediate_autoindex() {
    local files
    local -a modified_files
    local -a backup_files

    if ! files="$(nginx -T 2>/dev/null | awk '/^# configuration file /{print $4}' | sed 's/:$//')"; then
        return 1
    fi

    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        if grep -Eqi '^[[:space:]]*autoindex[[:space:]]+on[[:space:]]*;' "$file"; then
            local backup="${file}.bak.$(date +%s%N)"
            cp "$file" "$backup" || return 1

            sed -i -E \
                's/^([[:space:]]*)autoindex[[:space:]]+[Oo][Nn]([[:space:]]*;)/\1autoindex off\2/g' \
                "$file"

            modified_files+=("$file")
            backup_files+=("$backup")
        fi
    done <<< "$files"

    if ! nginx -t >/dev/null 2>&1; then
        for i in "${!modified_files[@]}"; do
            mv "${backup_files[$i]}" "${modified_files[$i]}"
        done
        return 1
    fi

    if [[ "${#modified_files[@]}" -gt 0 ]]; then
        nginx -s reload >/dev/null 2>&1

        for backup in "${backup_files[@]}"; do
            rm -f "$backup"
        done

        return 0
    fi

    return 1
}