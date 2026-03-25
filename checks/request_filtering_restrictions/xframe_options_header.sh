#!/usr/bin/env bash

# CIS 5.3.1 – Ensure X-Frame-Options header is configured and enabled
# Automation Level: Automated (Strict Enforcement)

check_x_frame_options() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local errors=""
    local has_header=0

    while read -r file line val; do
        has_header=1

        local val_upper="${val^^}"
        local policy=""
        local has_always=0

        # Extract first token as policy
        policy="${val_upper%% *}"

        if [[ "$val_upper" =~ (^|[[:space:]])ALWAYS($|[[:space:]]) ]]; then
            has_always=1
        fi

        if [[ "$policy" != "SAMEORIGIN" && "$policy" != "DENY" ]]; then
            errors+="  - [ERROR] X-Frame-Options in $file (line $line) is set to insecure policy '$val'.\n"
        fi

        if [[ "$has_always" -eq 0 ]]; then
            errors+="  - [ERROR] X-Frame-Options in $file (line $line) is missing the 'always' parameter.\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+/ {
            line_val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+/, "", line_val)
            sub(/;[[:space:]]*$/, "", line_val)

            # Strip only the header name quotes, preserve the full value
            if (match(line_val, /^["\047]?[Xx]-[Ff][Rr][Aa][Mm][Ee]-[Oo][Pp][Tt][Ii][Oo][Nn][Ss]["\047]?[[:space:]]+/)) {
                val = substr(line_val, RLENGTH + 1)
                gsub(/["\047]/, "", val)
                print file, line, val
            }
        }
    ')

    if [[ "$has_header" -eq 0 ]]; then
        errors+="  - 'X-Frame-Options' header is not configured.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Configure the X-Frame-Options header to protect against Clickjacking.\n"
        errors+="  - Add the following directive to your 'http' or 'server' block:\n"
        errors+="      add_header X-Frame-Options \"SAMEORIGIN\" always;"

        echo -e "${errors%\\n}"
        return 1
    fi

    return 0
}

remediate_x_frame_options() {

    command -v nginx >/dev/null 2>&1 || return 1

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local mod_files=()
    local has_header=0
    local fully_compliant=1

    while read -r file val; do
        has_header=1

        local val_upper="${val^^}"
        local policy="${val_upper%% *}"
        local has_always=0

        [[ "$val_upper" =~ (^|[[:space:]])ALWAYS($|[[:space:]]) ]] && has_always=1

        if [[ "$policy" != "SAMEORIGIN" && "$policy" != "DENY" ]] || [[ "$has_always" -eq 0 ]]; then
            fully_compliant=0
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

        /^[[:space:]]*add_header[[:space:]]+/ {
            line_val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+/, "", line_val)
            sub(/;[[:space:]]*$/, "", line_val)

            if (match(line_val, /^["\047]?[Xx]-[Ff][Rr][Aa][Mm][Ee]-[Oo][Pp][Tt][Ii][Oo][Nn][Ss]["\047]?[[:space:]]+/)) {
                val = substr(line_val, RLENGTH + 1)
                gsub(/["\047]/, "", val)
                print file, val
            }
        }
    ')

    if [[ "$has_header" -eq 1 && "$fully_compliant" -eq 1 ]]; then
        return 0
    fi

    backup_target() {
        local target="$1"
        for entry in "${backups[@]}"; do
            [[ "${entry%%:*}" == "$target" ]] && return 0
        done
        local b_file="${target}.bak.$(date +%s)"
        cp -p "$target" "$b_file" || return 1
        backups+=("$target:$b_file")
    }

    local file
    for file in "${mod_files[@]}"; do
        [[ -f "$file" ]] || continue
        backup_target "$file"

        awk '
            /^[[:space:]]*#/ { print; next }

            /^[[:space:]]*add_header[[:space:]]+["\047]?[Xx]-[Ff][Rr][Aa][Mm][Ee]-[Oo][Pp][Tt][Ii][Oo][Nn][Ss]["\047]?/ {
                match($0, /^[[:space:]]*/)
                indent = substr($0, RSTART, RLENGTH)
                print indent "add_header X-Frame-Options \"SAMEORIGIN\" always;"
                next
            }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    done

    if [[ "$has_header" -eq 0 ]]; then
        [[ -f "$main_config" ]] || return 1
        backup_target "$main_config" || return 1

        awk '
            /^[[:space:]]*#/ { print; next }

            /^[[:space:]]*http[[:space:]]*\{/ && !done {
                print
                print "    add_header X-Frame-Options \"SAMEORIGIN\" always;"
                done=1
                next
            }

            { print }
        ' "$main_config" > "${main_config}.tmp" && mv "${main_config}.tmp" "$main_config"
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