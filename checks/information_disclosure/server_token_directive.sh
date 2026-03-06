#!/usr/bin/env bash

# CIS 2.5.1 – Ensure server_tokens directive is set to off
# Automation Level: Automated

check_server_tokens() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local directive_found=0

    while read -r file line val; do
        directive_found=1
        if [[ "$val" != "off" ]]; then
            errors+="  - server_tokens is set to '$val' in $file (line $line)\n"
        fi
    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*server_tokens[[:space:]]+/ {
            val=$2; sub(/;/,"",val)
            print file, line, val
        }
    ')

    if [[ "$directive_found" -eq 0 ]]; then
        errors+="  - server_tokens directive is not configured (default is ON)\n"
    fi

    local header
    header=$(curl -s -k -I --connect-timeout 2 --max-time 3 http://127.0.0.1 2>/dev/null | grep -i '^Server:')

    if [[ -n "$header" && "$header" =~ nginx/ ]]; then
        errors+="  - Server header exposes nginx version: ${header//$'\r'/}\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Add or update the following inside your 'http' or 'server' blocks:\n"
        errors+="      server_tokens off;"
        echo -e "${errors%\\n}"
    fi
}


remediate_server_tokens() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local modified_files=()
    local backups=()
    local directive_exists=0

    if nginx -T 2>/dev/null | grep -Eq '[[:space:]]server_tokens[[:space:]]+'; then
        directive_exists=1
    fi

    # UPDATED BLOCK (duplicate-safe)
    mapfile -t modified_files < <(
        nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); next }
        /^[[:space:]]*server_tokens[[:space:]]+/ {
            val=$2; sub(/;/,"",val);
            if (val != "off") print file
        }' | sort -u
    )

    if [[ ${#modified_files[@]} -gt 0 ]]; then
        for file in "${modified_files[@]}"; do

            [[ -f "$file" ]] || continue

            backup_file="${file}.bak.$(date +%s)"
            cp "$file" "$backup_file" || continue
            backups+=("$file:$backup_file")

            sed -i -E \
            's/^([[:space:]]*)server_tokens[[:space:]]+[^;]*;/\1server_tokens off;/' \
            "$file"
        done

    elif [[ "$directive_exists" -eq 0 ]]; then

        [[ -f "$main_config" ]] || return 1

        backup_file="${main_config}.bak.$(date +%s)"
        cp "$main_config" "$backup_file" || return 1
        backups+=("$main_config:$backup_file")

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i '/http[[:space:]]*{/a \    server_tokens off;' "$main_config"
        else
            return 1
        fi

    else
        return 1
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