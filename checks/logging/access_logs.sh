#!/usr/bin/env bash

# CIS 3.2 – Ensure access logging is enabled
# Automation Level: Automated

check_access_logging() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_on=0
    local has_off=0

    while read -r file line val; do
        if [[ "$val" == "off" ]]; then
            has_off=1
            errors+="  - access_log is disabled ('off') in $file (line $line)\n"
        else
            has_on=1
        fi
    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*access_log[[:space:]]+/ {
            val=$2; sub(/;/,"",val)
            print file, line, val
        }
    ')

    if [[ "$has_on" -eq 0 ]]; then
        errors+="  - No active 'access_log' directives found in configuration.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Edit your NGINX configuration and ensure access logging is enabled.\n"
        errors+="  - Remove or comment out any 'access_log off;' directives.\n"
        errors+="  - Example configuration to add inside your 'http' or 'server' block:\n"
        errors+="      access_log /var/log/nginx/access.log;"
        echo -e "${errors%\\n}"
    fi
}


remediate_access_logging() {

    command -v nginx >/dev/null 2>&1 || return 1

    local main_config="/etc/nginx/nginx.conf"
    local backups=()
    local has_on=0
    local has_off=0
    local modified_files=()

    # Discover configuration state and non-compliant files in a SINGLE pass
    while read -r file val; do
        if [[ "$val" == "off" ]]; then
            has_off=1
            local skip=0
            local f
            for f in "${modified_files[@]}"; do
                [[ "$f" == "$file" ]] && skip=1 && break
            done
            [[ "$skip" -eq 0 ]] && modified_files+=("$file")
        else
            has_on=1
        fi
    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); next }
        /^[[:space:]]*access_log[[:space:]]+/ {
            val=$2; sub(/;/,"",val)
            print file, val
        }
    ')

    # Exit early if already perfectly compliant
    if [[ "$has_off" -eq 0 && "$has_on" -eq 1 ]]; then
        return 0
    fi

    # Phase 1 — comment out 'access_log off;'
    if [[ ${#modified_files[@]} -gt 0 ]]; then
        local file
        for file in "${modified_files[@]}"; do
            [[ -f "$file" ]] || continue

            local backup_file="${file}.bak.$(date +%s)"
            cp "$file" "$backup_file" || continue
            backups+=("$file:$backup_file")

            sed -i -E \
            's/^([[:space:]]*)access_log[[:space:]]+off[[:space:]]*;/\1# access_log off;/' \
            "$file"
        done
    fi

    # Phase 2 — inject default logging if none exist
    if [[ "$has_on" -eq 0 ]]; then
        [[ -f "$main_config" ]] || return 1

        # Prevent double-backing up the main config if Phase 1 already touched it
        local main_backed_up=0
        local entry
        for entry in "${backups[@]}"; do
            if [[ "${entry%%:*}" == "$main_config" ]]; then
                main_backed_up=1
                break
            fi
        done

        if [[ "$main_backed_up" -eq 0 ]]; then
            local backup_file="${main_config}.bak.$(date +%s)"
            cp "$main_config" "$backup_file" || return 1
            backups+=("$main_config:$backup_file")
        fi

        if grep -Eq '^[[:space:]]*http[[:space:]]*\{' "$main_config"; then
            sed -i '/http[[:space:]]*{/a \    access_log /var/log/nginx/access.log;' "$main_config"
        else
            return 1
        fi
    fi

    # Validate configuration & Rollback
    if ! nginx -t >/dev/null 2>&1; then
        local entry orig bak
        for entry in "${backups[@]}"; do
            orig="${entry%%:*}"
            bak="${entry##*:}"
            [[ -f "$bak" ]] && mv "$bak" "$orig"
        done
        return 1
    fi

    # Cleanup
    local entry bak
    for entry in "${backups[@]}"; do
        bak="${entry##*:}"
        rm -f "$bak"
    done

    nginx -s reload >/dev/null 2>&1

    return 0
}