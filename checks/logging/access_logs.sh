#!/bin/bash

# CIS 3.2 – Ensure access logging is enabled
# Automated safe remediation

check_access_logging() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local config found=0 disabled=0
    config="$(nginx -T 2>/dev/null)"

    # Define regex patterns in variables to prevent Bash from interpreting the semicolons
    local re_off='^[[:space:]]*access_log[[:space:]]+off[[:space:]]*;'
    local re_on='^[[:space:]]*access_log[[:space:]]+[^;]+;'
    local re_off_simple='off[[:space:]]*;'

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ $re_off ]]; then
            disabled=1
        fi

        if [[ "$line" =~ $re_on ]] && [[ ! "$line" =~ $re_off_simple ]]; then
            found=1
        fi
    done <<< "$config"

    if [[ "$found" -eq 1 && "$disabled" -eq 0 ]]; then
        pass "Access logging is enabled"
        return
    fi

    remediate_access_logging
}

remediate_access_logging() {

    local files
    local -a modified_files
    local -a backup_files

    # Fixed: Removed the trailing colon that Nginx attaches to file paths in config dumps
    files="$(nginx -T 2>/dev/null | awk '/^# configuration file /{print $4}' | sed 's/:$//')"

    while IFS= read -r file; do
        [[ -f "$file" ]] || continue

        if grep -Eq '^[[:space:]]*access_log[[:space:]]+off[[:space:]]*;' "$file"; then
            local backup="${file}.bak.$(date +%s%N)"
            cp "$file" "$backup" || { fail "backup failed"; return; }

            sed -i -E \
            's/^([[:space:]]*)access_log[[:space:]]+off[[:space:]]*;/\1# access_log off;/' \
            "$file"

            modified_files+=("$file")
            backup_files+=("$backup")
        fi
    done <<< "$files"

    local new_config
    new_config="$(nginx -T 2>/dev/null)"

    if ! echo "$new_config" | grep -Eq '^[[:space:]]*access_log[[:space:]]+[^;]+;' ; then
        local main
        main=$(nginx -V 2>&1 | grep -- '--conf-path' | sed -e 's/.*--conf-path=\([^ ]*\).*/\1/')
        if [ -z "$main" ]; then
            main="/etc/nginx/nginx.conf"
        fi
        
        local backup="${main}.bak.$(date +%s%N)"

        cp "$main" "$backup" || { fail "backup failed"; return; }

        # Fixed: Standardized whitespace in the sed append command
        sed -i '/http[[:space:]]*{/a \    access_log /var/log/nginx/access.log main;' "$main"

        modified_files+=("$main")
        backup_files+=("$backup")
    fi

    if ! nginx -t >/dev/null 2>&1; then
        for i in "${!modified_files[@]}"; do
            mv "${backup_files[$i]}" "${modified_files[$i]}"
        done
        fail "nginx configuration invalid after remediation"
        return
    fi

    nginx -s reload >/dev/null 2>&1

    local verify
    verify="$(nginx -T 2>/dev/null)"

    if echo "$verify" | grep -Eq '^[[:space:]]*access_log[[:space:]]+[^;]+;' && \
       ! echo "$verify" | grep -Eq '^[[:space:]]*access_log[[:space:]]+off[[:space:]]*;' ; then

        for backup in "${backup_files[@]}"; do
            rm -f "$backup"
        done

        pass "Access logging remediated"
    else
        for i in "${!modified_files[@]}"; do
            mv "${backup_files[$i]}" "${modified_files[$i]}"
        done
        nginx -t >/dev/null 2>&1 && nginx -s reload >/dev/null 2>&1
        fail "Access logging remediation failed"
    fi
}