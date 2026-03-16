#!/usr/bin/env bash

# CIS 4.1.6 – Ensure custom Diffie-Hellman parameters are used
# Automation Level: Automated (Note: DH parameter generation may take a few moments)

check_ssl_dhparam() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    command -v openssl >/dev/null 2>&1 || {
        echo "openssl binary not found (required for DH parameter checks)"
        return 1
    }

    local errors=""
    local has_dhparam=0
    local dhparams=()

    while read -r file line val; do
        has_dhparam=1
        dhparams+=("$file|$line|$val")
    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*ssl_dhparam[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*ssl_dhparam[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            gsub(/["\047]/, "", val)
            print file, line, val
        }
    ')

    if [[ "$has_dhparam" -eq 0 ]]; then
        errors+="  - 'ssl_dhparam' directive is missing from configuration.\n"
    else
        local entry
        for entry in "${dhparams[@]}"; do

            local conf_file="${entry%%|*}"
            local rest="${entry#*|}"
            local line="${rest%%|*}"
            local dh_file="${rest#*|}"

            if [[ ! -f "$dh_file" ]]; then
                errors+="  - ssl_dhparam file does not exist: $dh_file (referenced in $conf_file line $line)\n"
                continue
            fi

            local bits
            bits=$(openssl dhparam -in "$dh_file" -text -noout 2>/dev/null | awk '
                /[0-9]+[[:space:]]*bit/ {
                    match($0, /[0-9]+/)
                    print substr($0, RSTART, RLENGTH)
                    exit
                }
            ')

            if [[ -z "$bits" ]]; then
                errors+="  - Unable to determine DH parameter size for $dh_file\n"
            elif [[ "$bits" -lt 2048 ]]; then
                errors+="  - DH parameters in $dh_file are too weak ($bits bits). Expected >= 2048.\n"
            fi
        done
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Generate strong DH parameters:\n"
        errors+="      mkdir -p /etc/nginx/ssl\n"
        errors+="      openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048\n"
        errors+="      chmod 400 /etc/nginx/ssl/dhparam.pem\n"
        errors+="  - Add the following directive to your 'http' or 'server' block:\n"
        errors+="      ssl_dhparam /etc/nginx/ssl/dhparam.pem;"

        echo -e "${errors%\\n}"
    fi
}

remediate_ssl_dhparam() {

    command -v nginx >/dev/null 2>&1 || return 1
    command -v openssl >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local std_dh_file="/etc/nginx/ssl/dhparam.pem"
    local backups=()
    local mod_files=()
    local has_dhparam=0
    local is_fully_compliant=1

    while read -r file val; do

        has_dhparam=1
        local valid=0

        if [[ -f "$val" ]]; then
            local bits
            bits=$(openssl dhparam -in "$val" -text -noout 2>/dev/null | awk '
                /[0-9]+[[:space:]]*bit/ {
                    match($0, /[0-9]+/)
                    print substr($0, RSTART, RLENGTH)
                    exit
                }
            ')

            if [[ -n "$bits" && "$bits" -ge 2048 ]]; then
                valid=1
            fi
        fi

        if [[ "$valid" -eq 0 ]]; then
            is_fully_compliant=0
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

        /^[[:space:]]*ssl_dhparam[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*ssl_dhparam[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            gsub(/["\047]/, "", val)
            print file, val
        }
    ')

    if [[ "$has_dhparam" -eq 1 && "$is_fully_compliant" -eq 1 ]]; then
        return 0
    fi

    local gen_dh=1

    if [[ -f "$std_dh_file" ]]; then
        local std_bits
        std_bits=$(openssl dhparam -in "$std_dh_file" -text -noout 2>/dev/null | awk '
            /[0-9]+[[:space:]]*bit/ {
                match($0, /[0-9]+/)
                print substr($0, RSTART, RLENGTH)
                exit
            }
        ')

        if [[ -n "$std_bits" && "$std_bits" -ge 2048 ]]; then
            gen_dh=0
        fi
    fi

    if [[ "$gen_dh" -eq 1 ]]; then
        mkdir -p /etc/nginx/ssl || return 1
        openssl dhparam -out "$std_dh_file" 2048 >/dev/null 2>&1 || return 1
        chmod 400 "$std_dh_file" || return 1
    fi

    backup_target() {
        local target="$1"

        local entry
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

        # Safe regex: Anchored to ^, preserves indentation, only modifies active directives
        sed -i -E \
        "s|^([[:space:]]*ssl_dhparam[[:space:]]+)[^;]+;|\1${std_dh_file};|" \
        "$file"
    done

    if [[ "$has_dhparam" -eq 0 ]]; then

        [[ -f "$main_config" ]] || return 1
        backup_target "$main_config" || return 1

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i "/http[[:space:]]*{/a \    ssl_dhparam ${std_dh_file};" "$main_config"
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