#!/usr/bin/env bash

# CIS 3.3 – Ensure error logging is enabled and set to info level
# Automation Level: Automated

check_error_logging() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_info=0
    local has_any=0

    while read -r file line val; do
        has_any=1

        if [[ "$val" =~ (^|[[:space:]])info$ ]]; then
            has_info=1
        else
            errors+="  - error_log in $file (line $line) is not set to 'info' level (currently: $val)\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*error_log[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*error_log[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, val
        }
    ')

    if [[ "$has_any" -eq 0 ]]; then
        errors+="  - No 'error_log' directives found in configuration. (NGINX defaults to 'error' level)\n"

    elif [[ "$has_info" -eq 0 ]]; then
        errors+="  - No 'error_log' directive is set to the required 'info' level.\n"
    fi


    if [[ -n "$errors" ]]; then

        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit your NGINX configuration and ensure error logging is set to 'info'.\n"
        errors+="  - Example configuration:\n"
        errors+="      error_log /var/log/nginx/error.log info;"

        echo -e "${errors%\\n}"
    fi
}


remediate_error_logging() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local modified_files=()
    local has_info=0
    local has_any=0

    while read -r file val; do

        has_any=1

        if [[ "$val" =~ (^|[[:space:]])info$ ]]; then
            has_info=1
        else

            local skip=0
            local f

            for f in "${modified_files[@]}"; do
                [[ "$f" == "$file" ]] && skip=1 && break
            done

            [[ "$skip" -eq 0 ]] && modified_files+=("$file")
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); next }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*error_log[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*error_log[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, val
        }
    ')


    if [[ "$has_any" -eq 1 && "$has_info" -eq 1 && ${#modified_files[@]} -eq 0 ]]; then
        return 0
    fi


    if [[ ${#modified_files[@]} -gt 0 ]]; then

        local file

        for file in "${modified_files[@]}"; do

            [[ -f "$file" ]] || continue

            local backup_file="${file}.bak.$(date +%s)"

            cp "$file" "$backup_file" || continue
            backups+=("$file:$backup_file")

            sed -i -E \
            's/^([[:space:]]*error_log[[:space:]]+[^[:space:];]+)([[:space:]]+[a-z]+)?[[:space:]]*;/\1 info;/' \
            "$file"
        done
    fi


    if [[ "$has_any" -eq 0 ]]; then

        [[ -f "$main_config" ]] || return 1

        local backup_file="${main_config}.bak.$(date +%s)"
        cp "$main_config" "$backup_file" || return 1

        backups+=("$main_config:$backup_file")

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i '/http[[:space:]]*{/a \    error_log /var/log/nginx/error.log info;' "$main_config"
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