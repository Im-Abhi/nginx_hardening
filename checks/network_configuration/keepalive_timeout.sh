#!/usr/bin/env bash

# CIS 2.4.3 – Ensure keepalive_timeout is 10 seconds or less, but not 0
# Automation Level: Automated

check_keepalive_timeout() {

    local errors=""
    local found=0

    while read -r file line_num value; do
        found=1

        local seconds

        if [[ "$value" =~ ms$ ]]; then
            seconds=$(( ${value%ms} / 1000 ))
        elif [[ "$value" =~ s$ ]]; then
            seconds=${value%s}
        else
            seconds=$value
        fi

        if [[ "$seconds" -eq 0 ]]; then
            errors+="  - keepalive_timeout is set to 0 in $file (Line $line_num)\n"
        elif [[ "$seconds" -gt 10 ]]; then
            errors+="  - keepalive_timeout is greater than 10 seconds ($value) in $file (Line $line_num)\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; line=0; sub(/:$/, "", file); next }
        { line++ }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*keepalive_timeout[[:space:]]+/ {
            sub(/;/, "", $2)
            print file, line, $2
        }
    ')

    if [[ "$found" -eq 0 ]]; then
        errors+="  - keepalive_timeout directive is not configured (defaults to 75s)\n"
    fi

    if [[ -n "$errors" ]]; then
        echo -e "${errors%\\n}"
    fi
}


remediate_keepalive_timeout() {
    local main_config="/etc/nginx/nginx.conf"
    local modified_files=()
    local backups=()
    local found=0

    # 1. Parse config to find exactly which files contain the directive
    while read -r file; do
        found=1

        local skip=0
        local f
        for f in "${modified_files[@]}"; do
            [[ "$f" == "$file" ]] && skip=1 && break
        done
        [[ "$skip" -eq 0 ]] && modified_files+=("$file")

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/, "", file); next }
        /^[[:space:]]*keepalive_timeout[[:space:]]+/ { print file }
    ')

    # 2. Update existing files
    if [[ "$found" -eq 1 ]]; then
        local file
        for file in "${modified_files[@]}"; do
            [[ -f "$file" ]] || continue

            local backup_file="${file}.bak.$(date +%s)"
            cp "$file" "$backup_file" || continue
            backups+=("$file:$backup_file")

            sed -i -E \
            's/^([[:space:]]*)keepalive_timeout[[:space:]]+[^;]+;/\1keepalive_timeout 10;/' \
            "$file"
        done
    # 3. Inject into main config if missing entirely
    else
        [[ -f "$main_config" ]] || return 1

        local backup_file="${main_config}.bak.$(date +%s)"
        cp "$main_config" "$backup_file" || return 1
        backups+=("$main_config:$backup_file")

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i '/http[[:space:]]*{/a \    keepalive_timeout 10;' "$main_config"
        else
            return 1
        fi
    fi

    # 4. Validate and Rollback
    if ! nginx -t >/dev/null 2>&1; then
        local entry orig bak
        for entry in "${backups[@]}"; do
            orig="${entry%%:*}"
            bak="${entry##*:}"
            [[ -f "$bak" ]] && mv "$bak" "$orig"
        done
        return 1
    fi

    # 5. Cleanup and Apply
    local entry bak
    for entry in "${backups[@]}"; do
        bak="${entry##*:}"
        rm -f "$bak"
    done

    nginx -s reload >/dev/null 2>&1
    return 0
}