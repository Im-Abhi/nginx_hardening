#!/usr/bin/env bash

# CIS 3.4 – Ensure log files are rotated
# Automation Level: Automated

check_log_rotation() {

    local target_file="/etc/logrotate.d/nginx"
    local errors=""

    if [[ ! -f "$target_file" ]]; then
        errors+="  - NGINX logrotate configuration not found at $target_file\n"
    else

        # Ignore commented lines when checking directives
        if ! grep -Ev '^[[:space:]]*#' "$target_file" | grep -Eq '^[[:space:]]*weekly\b'; then
            errors+="  - Log rotation is not set to 'weekly'\n"
        fi

        if ! grep -Ev '^[[:space:]]*#' "$target_file" | grep -Eq '^[[:space:]]*rotate[[:space:]]+13\b'; then
            errors+="  - Log retention is not set to 'rotate 13'\n"
        fi
    fi


    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit $target_file and ensure the following directives exist:\n"
        errors+="      weekly\n"
        errors+="      rotate 13\n"
        errors+="  - Always comply with organizational log retention policies if different values are required."

        echo -e "${errors%\\n}"
    fi
}


remediate_log_rotation() {

    local target_file="/etc/logrotate.d/nginx"

    [[ -f "$target_file" ]] || return 1
    command -v logrotate >/dev/null 2>&1 || return 1

    local backup_file="${target_file}.bak.$(date +%s)"

    cp "$target_file" "$backup_file" || return 1


    # Replace daily/monthly/yearly with weekly (ignore commented lines)
    if grep -Ev '^[[:space:]]*#' "$target_file" | grep -Eq '^[[:space:]]*(daily|monthly|yearly)\b'; then

        sed -i -E '/^[[:space:]]*#/! s/^([[:space:]]*)(daily|monthly|yearly)\b/\1weekly/' "$target_file"

    elif ! grep -Ev '^[[:space:]]*#' "$target_file" | grep -Eq '^[[:space:]]*weekly\b'; then

        # Insert weekly after first block opening
        awk '/\{/ && !done { print; print "    weekly"; done=1; next } 1' \
            "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
    fi


    # Replace rotate value (ignore commented lines)
    if grep -Ev '^[[:space:]]*#' "$target_file" | grep -Eq '^[[:space:]]*rotate[[:space:]]+[0-9]+'; then

        sed -i -E '/^[[:space:]]*#/! s/^([[:space:]]*)rotate[[:space:]]+[0-9]+/\1rotate 13/' "$target_file"

    elif ! grep -Ev '^[[:space:]]*#' "$target_file" | grep -Eq '^[[:space:]]*rotate[[:space:]]+13\b'; then

        awk '/\{/ && !done { print; print "    rotate 13"; done=1; next } 1' \
            "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
    fi


    # Validate syntax using logrotate debug mode
    if ! logrotate -d "$target_file" >/dev/null 2>&1; then
        mv "$backup_file" "$target_file"
        rm -f "${target_file}.tmp"
        return 1
    fi


    rm -f "$backup_file" "${target_file}.tmp"

    return 0
}