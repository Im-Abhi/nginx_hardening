#!/usr/bin/env bash

# CIS 4.1.4 – Ensure only modern TLS protocols are used
# Automation Level: Automated

check_ssl_protocols() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_ssl=0
    local has_proxy_pass=0
    local has_proxy_ssl=0

    while read -r file line type val; do

        if [[ "$type" == "proxy_pass" ]]; then
            has_proxy_pass=1
            continue
        fi

        if [[ "$type" == "ssl_protocols" ]]; then
            has_ssl=1
        elif [[ "$type" == "proxy_ssl_protocols" ]]; then
            has_proxy_ssl=1
        fi

        # FIXED REGEX HERE
        if grep -Eq 'SSLv[23]|TLSv1(\.0|\.1)?([[:space:]]|$)' <<< "$val"; then
            errors+="  - $type in $file (line $line) enables insecure protocols: $val\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*proxy_pass[[:space:]]+/ {
            print file, line, "proxy_pass", "N/A"
        }

        /^[[:space:]]*(ssl_protocols|proxy_ssl_protocols)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(ssl_protocols|proxy_ssl_protocols)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, type, val
        }
    ')

    if [[ "$has_ssl" -eq 0 ]]; then
        errors+="  - 'ssl_protocols' directive is missing (NGINX default may be insecure).\n"
    fi

    if [[ "$has_proxy_pass" -eq 1 && "$has_proxy_ssl" -eq 0 ]]; then
        errors+="  - NGINX acts as a proxy (proxy_pass found) but 'proxy_ssl_protocols' is missing.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Restrict TLS protocols to modern standards.\n"
        errors+="  - Example configuration:\n"
        errors+="      ssl_protocols TLSv1.2 TLSv1.3;\n"

        if [[ "$has_proxy_pass" -eq 1 ]]; then
            errors+="      proxy_ssl_protocols TLSv1.2 TLSv1.3;\n"
        fi

        echo -e "${errors%\\n}"
    fi
}

remediate_ssl_protocols() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local mod_ssl_files=()
    local mod_proxy_files=()
    local has_ssl=0
    local has_proxy_pass=0
    local has_proxy_ssl=0

    while read -r type file val; do

        if [[ "$type" == "proxy_pass" ]]; then
            has_proxy_pass=1

        elif [[ "$type" == "ssl_protocols" ]]; then
            has_ssl=1

            # FIXED REGEX HERE
            if grep -Eq 'SSLv[23]|TLSv1(\.0|\.1)?([[:space:]]|$)' <<< "$val"; then
                local skip=0
                local f
                for f in "${mod_ssl_files[@]}"; do [[ "$f" == "$file" ]] && skip=1 && break; done
                [[ "$skip" -eq 0 ]] && mod_ssl_files+=("$file")
            fi

        elif [[ "$type" == "proxy_ssl_protocols" ]]; then
            has_proxy_ssl=1

            # FIXED REGEX HERE
            if grep -Eq 'SSLv[23]|TLSv1(\.0|\.1)?([[:space:]]|$)' <<< "$val"; then
                local skip=0
                local f
                for f in "${mod_proxy_files[@]}"; do [[ "$f" == "$file" ]] && skip=1 && break; done
                [[ "$skip" -eq 0 ]] && mod_proxy_files+=("$file")
            fi
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); next }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*proxy_pass[[:space:]]+/ { print "proxy_pass", file, "N/A" }

        /^[[:space:]]*(ssl_protocols|proxy_ssl_protocols)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(ssl_protocols|proxy_ssl_protocols)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print type, file, val
        }
    ')

    if [[ "$has_ssl" -eq 1 && ${#mod_ssl_files[@]} -eq 0 ]]; then
        if [[ "$has_proxy_pass" -eq 0 || ("$has_proxy_pass" -eq 1 && "$has_proxy_ssl" -eq 1 && ${#mod_proxy_files[@]} -eq 0) ]]; then
            return 0
        fi
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

    for file in "${mod_ssl_files[@]}"; do
        [[ -f "$file" ]] && backup_target "$file" &&
        sed -i -E 's/^([[:space:]]*ssl_protocols[[:space:]]+)[^;]+;/\1TLSv1.2 TLSv1.3;/' "$file"
    done

    for file in "${mod_proxy_files[@]}"; do
        [[ -f "$file" ]] && backup_target "$file" &&
        sed -i -E 's/[[:space:]]*proxy_ssl_protocols[[:space:]]+[^;]+;/    proxy_ssl_protocols TLSv1.2 TLSv1.3;/' "$file"
    done

    # Properly isolated injections
    if [[ "$has_ssl" -eq 0 || ("$has_proxy_pass" -eq 1 && "$has_proxy_ssl" -eq 0) ]]; then

        [[ -f "$main_config" ]] || return 1
        backup_target "$main_config" || return 1

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            if [[ "$has_ssl" -eq 0 ]]; then
                sed -i '/http[[:space:]]*{/a \    ssl_protocols TLSv1.2 TLSv1.3;' "$main_config"
            fi
            
            if [[ "$has_proxy_pass" -eq 1 && "$has_proxy_ssl" -eq 0 ]]; then
                sed -i '/http[[:space:]]*{/a \    proxy_ssl_protocols TLSv1.2 TLSv1.3;' "$main_config"
            fi
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