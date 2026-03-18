#!/usr/bin/env bash

# CIS 4.1.13 – Ensure HTTP/2 is used
# Automation Level: Automated

check_http2_enabled() {

    command -v nginx >/dev/null 2>&1 || return 1

    local errors=""
    local missing_listeners=()

    while read -r type file line val; do

        if [[ "$type" == "listen" ]]; then

            if [[ "$val" =~ (^|[[:space:]])ssl($|[[:space:]]) ]] &&
               ! [[ "$val" =~ (^|[[:space:]])http2($|[[:space:]]) ]]; then

                missing_listeners+=("  - HTTPS listener in $file (line $line) missing 'http2': listen $val;")
            fi
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*listen[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*listen[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print "listen", file, line, val
        }
    ')

    if [[ ${#missing_listeners[@]} -gt 0 ]]; then
        for err in "${missing_listeners[@]}"; do
            errors+="$err\n"
        done

        errors+="\n  Remediation:\n"
        errors+="      listen 443 ssl http2;"

        echo -e "${errors%\\n}"
    fi
}


remediate_http2_enabled() {

    command -v nginx >/dev/null 2>&1 || return 1

    local backups=()
    local mod_files=()

    while read -r type file val; do

        if [[ "$type" == "listen" ]]; then

            if [[ "$val" =~ (^|[[:space:]])ssl($|[[:space:]]) ]] &&
               ! [[ "$val" =~ (^|[[:space:]])http2($|[[:space:]]) ]]; then

                local skip=0
                for f in "${mod_files[@]}"; do
                    [[ "$f" == "$file" ]] && skip=1 && break
                done
                [[ "$skip" -eq 0 ]] && mod_files+=("$file")
            fi
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); next }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*listen[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*listen[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print "listen", file, val
        }
    ')

    [[ ${#mod_files[@]} -eq 0 ]] && return 0

    backup_target() {
        local target="$1"
        for entry in "${backups[@]}"; do
            [[ "${entry%%:*}" == "$target" ]] && return 0
        done
        local b_file="${target}.bak.$(date +%s)"
        cp "$target" "$b_file" || return 1
        backups+=("$target:$b_file")
    }

    for file in "${mod_files[@]}"; do
        [[ -f "$file" ]] || continue
        backup_target "$file"

        awk '
            /^[[:space:]]*#/ { print; next }

            /^[[:space:]]*listen[[:space:]]+.*ssl/ {
                if ($0 !~ /http2/) {
                    sub(/;[[:space:]]*$/, " http2;", $0)
                }
            }
            1
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    done

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