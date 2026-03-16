#!/usr/bin/env bash

# CIS 4.1.8 – Ensure HTTP Strict Transport Security (HSTS) is enabled
# Automation Level: Automated

check_hsts_configuration() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_hsts=0

    while read -r file line val; do
        has_hsts=1

        local max_age=""

        if [[ "$val" =~ max-age=([0-9]+) ]]; then
            max_age="${BASH_REMATCH[1]}"
        fi

        if [[ -z "$max_age" ]]; then
            errors+="  - HSTS in $file (line $line) missing 'max-age'.\n"
        elif [[ "$max_age" -lt 15768000 ]]; then
            errors+="  - HSTS in $file (line $line) max-age too low (${max_age}s). Expected >= 15768000.\n"
        fi

        if ! [[ "$val" =~ (^|[[:space:]])always($|[[:space:]]) ]]; then
            errors+="  - HSTS in $file (line $line) missing 'always' parameter.\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, val
        }
    ')

    [[ "$has_hsts" -eq 0 ]] &&
    errors+="  - HSTS header is missing from configuration.\n"

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Enable HSTS with minimum 6 months max-age.\n"
        errors+="  - Example configuration:\n"
        errors+="      add_header Strict-Transport-Security \"max-age=15768000;\" always;"
        echo -e "${errors%\\n}"
    fi
}


remediate_hsts_configuration() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local mod_files=()
    local has_hsts=0

    while read -r file val; do
        has_hsts=1

        local valid=1
        local max_age=""

        if [[ "$val" =~ max-age=([0-9]+) ]]; then
            max_age="${BASH_REMATCH[1]}"
        fi

        if [[ -z "$max_age" || "$max_age" -lt 15768000 ]]; then
            valid=0
        fi

        if ! [[ "$val" =~ (^|[[:space:]])always($|[[:space:]]) ]]; then
            valid=0
        fi

        if [[ "$valid" -eq 0 ]]; then
            local skip=0
            local f
            for f in "${mod_files[@]}"; do
                [[ "$f" == "$file" ]] && skip=1 && break
            done
            [[ "$skip" -eq 0 ]] && mod_files+=("$file")
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); next }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, val
        }
    ')

    if [[ "$has_hsts" -eq 1 && ${#mod_files[@]} -eq 0 ]]; then
        return 0
    fi

    backup_target() {
        local target="$1"
        for entry in "${backups[@]}"; do
            [[ "${entry%%:*}" == "$target" ]] && return 0
        done

        local b_file="${target}.bak.$(date +%s)"
        cp "$target" "$b_file" || return 1
        backups+=("$target:$b_file")
    }

    local file
    for file in "${mod_files[@]}"; do

        [[ -f "$file" ]] || continue
        backup_target "$file"

        sed -i -E \
        's/^([[:space:]]*add_header[[:space:]]+["\047]?Strict-Transport-Security["\047]?[[:space:]]+)[^;]*;[[:space:]]*/\1"max-age=15768000;" always;/' \
        "$file"
    done

    if [[ "$has_hsts" -eq 0 ]]; then

        [[ -f "$main_config" ]] || return 1
        backup_target "$main_config" || return 1

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i '/http[[:space:]]*{/a \
    add_header Strict-Transport-Security "max-age=15768000;" always;' "$main_config"
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

    for entry in "${backups[@]}"; do
        rm -f "${entry##*:}"
    done

    nginx -s reload >/dev/null 2>&1
    return 0
}