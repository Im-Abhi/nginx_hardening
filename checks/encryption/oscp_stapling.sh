#!/usr/bin/env bash

# CIS 4.1.7 – Ensure OCSP stapling is enabled
# Automation Level: Automated

check_ocsp_stapling() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_stapling=0
    local has_verify=0

    while read -r file line type val; do

        val="${val%% *}"

        if [[ "$type" == "ssl_stapling" ]]; then
            has_stapling=1
            [[ "$val" != "on" ]] &&
            errors+="  - $type in $file (line $line) is not set to 'on' (currently: $val)\n"

        elif [[ "$type" == "ssl_stapling_verify" ]]; then
            has_verify=1
            [[ "$val" != "on" ]] &&
            errors+="  - $type in $file (line $line) is not set to 'on' (currently: $val)\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*(ssl_stapling|ssl_stapling_verify)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(ssl_stapling|ssl_stapling_verify)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, type, val
        }
    ')

    [[ "$has_stapling" -eq 0 ]] &&
    errors+="  - 'ssl_stapling' directive is missing (NGINX default is OFF).\n"

    [[ "$has_verify" -eq 0 ]] &&
    errors+="  - 'ssl_stapling_verify' directive is missing (NGINX default is OFF).\n"

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Ensure your NGINX server has network access to the OCSP responder.\n"
        errors+="  - Enable OCSP stapling:\n"
        errors+="      ssl_stapling on;\n"
        errors+="      ssl_stapling_verify on;"

        echo -e "${errors%\\n}"
    fi
}

remediate_ocsp_stapling() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local mod_files=()
    local has_stapling=0
    local has_verify=0

    while read -r type file val; do

        val="${val%% *}"

        [[ "$type" == "ssl_stapling" ]] && has_stapling=1
        [[ "$type" == "ssl_stapling_verify" ]] && has_verify=1

        if [[ "$val" != "on" ]]; then
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

        /^[[:space:]]*(ssl_stapling|ssl_stapling_verify)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(ssl_stapling|ssl_stapling_verify)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print type, file, val
        }
    ')

    if [[ "$has_stapling" -eq 1 && "$has_verify" -eq 1 && ${#mod_files[@]} -eq 0 ]]; then
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

        sed -i -E 's/^([[:space:]]*ssl_stapling[[:space:]]+)[^;]*;[[:space:]]*/\1on;/' "$file"
        sed -i -E 's/^([[:space:]]*ssl_stapling_verify[[:space:]]+)[^;]*;[[:space:]]*/\1on;/' "$file"
    done

    if [[ "$has_stapling" -eq 0 || "$has_verify" -eq 0 ]]; then

        [[ -f "$main_config" ]] || return 1
        backup_target "$main_config" || return 1

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then

            sed -i '/http[[:space:]]*{/a \
    ssl_stapling on;\
    ssl_stapling_verify on;' "$main_config"

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