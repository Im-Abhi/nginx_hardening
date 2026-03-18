#!/usr/bin/env bash

# CIS 4.1.12 – Ensure session resumption is disabled
# Automation Level: Automated

check_ssl_session_tickets_disabled() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_tickets=0

    while read -r file line val; do
        has_tickets=1

        local val_lower="${val,,}"
        val_lower="${val_lower%%[[:space:]]*}"

        if [[ "$val_lower" != "off" ]]; then
            errors+="  - ssl_session_tickets in $file (line $line) is '$val_lower' (Expected: off).\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*ssl_session_tickets[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*ssl_session_tickets[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, val
        }
    ')

    if [[ "$has_tickets" -eq 0 ]]; then
        errors+="  - ssl_session_tickets directive missing (defaults to ON).\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation:\n"
        errors+="      ssl_session_tickets off;"
        echo -e "${errors%\\n}"
    fi
}


remediate_ssl_session_tickets_disabled() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local mod_files=()
    local has_tickets=0


    while read -r file val; do
        has_tickets=1

        local val_lower="${val,,}"
        val_lower="${val_lower%%[[:space:]]*}"

        if [[ "$val_lower" != "off" ]]; then
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

        /^[[:space:]]*ssl_session_tickets[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*ssl_session_tickets[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, val
        }
    ')


    if [[ "$has_tickets" -eq 1 && ${#mod_files[@]} -eq 0 ]]; then
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

        sed -i.bak -E \
        's/^([[:space:]]*ssl_session_tickets[[:space:]]+)[^;]*;[[:space:]]*/\1off;/' \
        "$file" && rm -f "${file}.bak"
    done


    if [[ "$has_tickets" -eq 0 ]]; then

        [[ -f "$main_config" ]] || return 1
        backup_target "$main_config" || return 1

        awk '/http[[:space:]]*{/ && !done {
            print
            print "    ssl_session_tickets off;"
            done=1
            next
        } 1' "$main_config" > "${main_config}.tmp" && mv "${main_config}.tmp" "$main_config"
    fi


    if ! nginx -t >/dev/null 2>&1; then
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