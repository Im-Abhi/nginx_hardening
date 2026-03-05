#!/usr/bin/env bash

# CIS 2.4.4 – Ensure send_timeout is 10 seconds or less, but not 0
# Automation Level: Automated

check_send_timeout() {
    local errors=""
    local found=0

    # Parse the live NGINX config, track the originating file/line, and extract the timeout value
    while read -r file line_num value; do
        found=1

        local seconds

        # Handle NGINX time formats (s, ms, or raw seconds)
        if [[ "$value" =~ ms$ ]]; then
            seconds=$(( ${value%ms} / 1000 ))
        elif [[ "$value" =~ s$ ]]; then
            seconds=${value%s}
        else
            seconds=$value
        fi

        if [[ "$seconds" -eq 0 ]]; then
            errors+="  - send_timeout is set to 0 in $file (Line $line_num)\n"
        elif [[ "$seconds" -gt 10 ]]; then
            errors+="  - send_timeout is greater than 10 seconds ($value) in $file (Line $line_num)\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; line=0; sub(/:$/, "", file); next }
        { line++ }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*send_timeout[[:space:]]+/ {
            sub(/;/, "", $2)
            print file, line, $2
        }
    ')

    if [[ "$found" -eq 0 ]]; then
        errors+="  - send_timeout directive is not configured (defaults to 60s)\n"
    fi

    if [[ -n "$errors" ]]; then
        echo -e "${errors%\\n}"
    fi
}

remediate_send_timeout() {
    local main_config="/etc/nginx/nginx.conf"
    local modified_files=()
    local backups=()
    local found=0

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
        /^[[:space:]]*send_timeout[[:space:]]+/ { print file }
    ')

    if [[ "$found" -eq 1 ]]; then
        local file
        for file in "${modified_files[@]}"; do
            [[ -f "$file" ]] || continue

            local backup_file="${file}.bak.$(date +%s)"
            cp "$file" "$backup_file" || continue
            backups+=("$file:$backup_file")

            sed -i -E \
            's/^([[:space:]]*)send_timeout[[:space:]]+[^;]+;/\1send_timeout 10;/' \
            "$file"
        done
    else
        [[ -f "$main_config" ]] || return 1

        local backup_file="${main_config}.bak.$(date +%s)"
        cp "$main_config" "$backup_file" || return 1
        backups+=("$main_config:$backup_file")

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i '/http[[:space:]]*{/a \    send_timeout 10;' "$main_config"
        else
            return 1
        fi
    fi

    if ! nginx -t >/dev/null 2>&1; then
        local entry orig bak
        for entry in "${backups[@]}"; do
            orig="${entry%%:*}"
            bak="${entry##*:}"
            [[ -f "$bak" ]] && mv "$bak" "$orig"
        done
        return 1
    fi

    local entry bak
    for entry in "${backups[@]}"; do
        bak="${entry##*:}"
        rm -f "$bak"
    done

    nginx -s reload >/dev/null 2>&1
    return 0
}