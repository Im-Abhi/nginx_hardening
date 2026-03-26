#!/usr/bin/env bash

# CIS 5.3.2 – Ensure X-Content-Type-Options header is configured and enabled
# Automation Level: Automated (Strict Enforcement)

check_x_content_type_options() {

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

        # Normalize repeated spaces
        val_upper="$(echo "$val_upper" | awk '{$1=$1; print}')"

        if [[ ! "$val_upper" =~ ^NOSNIFF([[:space:]]+ALWAYS)?$ ]]; then
            errors+="  - [ERROR] X-Content-Type-Options in $file (line $line) has invalid value '$val'. Expected: 'nosniff' with optional 'always'.\n"
        fi

        if ! [[ "$val_upper" =~ (^|[[:space:]])ALWAYS($|[[:space:]]) ]]; then
            errors+="  - [ERROR] X-Content-Type-Options in $file (line $line) is missing the 'always' parameter.\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+/ {
            line_val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+/, "", line_val)
            sub(/;[[:space:]]*$/, "", line_val)

            if (match(line_val, /^["\047]?[Xx]-[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]-[Oo][Pp][Tt][Ii][Oo][Nn][Ss]["\047]?[[:space:]]+/)) {
                val = substr(line_val, RLENGTH + 1)
                gsub(/["\047]/, "", val)
                print file, line, val
            }
        }
    ')

    if [[ "$has_header" -eq 0 ]]; then
        errors+="  - 'X-Content-Type-Options' header is not configured.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Configure the X-Content-Type-Options header to prevent MIME-sniffing attacks.\n"
        errors+="  - Add the following directive to your 'http' or 'server' block:\n"
        errors+="      add_header X-Content-Type-Options \"nosniff\" always;"

        echo -e "${errors%\\n}"
        return 1
    fi

    return 0
}

remediate_x_content_type_options() {

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
        val_upper="$(echo "$val_upper" | awk '{$1=$1; print}')"

        if [[ ! "$val_upper" =~ ^NOSNIFF([[:space:]]+ALWAYS)?$ ]] ||
           ! [[ "$val_upper" =~ (^|[[:space:]])ALWAYS($|[[:space:]]) ]]; then
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

            if (match(line_val, /^["\047]?[Xx]-[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]-[Oo][Pp][Tt][Ii][Oo][Nn][Ss]["\047]?[[:space:]]+/)) {
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

            /^[[:space:]]*add_header[[:space:]]+["\047]?[Xx]-[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]-[Oo][Pp][Tt][Ii][Oo][Nn][Ss]["\047]?/ {
                match($0, /^[[:space:]]*/)
                indent = substr($0, RSTART, RLENGTH)
                print indent "add_header X-Content-Type-Options \"nosniff\" always;"
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
                print "    add_header X-Content-Type-Options \"nosniff\" always;"
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