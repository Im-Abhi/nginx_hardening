#!/usr/bin/env bash

# CIS 2.3.4 – Ensure the core dump directory is secured
# Automation Level: Manual

check_core_dump_directory() {
    local config working_dir
    local service_user service_group
    local errors=""

    # -------- Prerequisite --------
    if ! nginx -t >/dev/null 2>&1; then
        echo "MANUAL: nginx configuration invalid"
        return 0
    fi

    if ! config="$(nginx -T 2>/dev/null)"; then
        echo "MANUAL: nginx configuration dump failed"
        return 0
    fi

    # -------- Extract working_directory --------
    working_dir="$(echo "$config" | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*working_directory[[:space:]]+/ {
            gsub(";", "", $2)
            print $2
            exit
        }
    ')"

    # If not configured → compliant
    if [[ -z "$working_dir" ]]; then
        return 0
    fi

    # -------- Extract Service Account --------
    service_user="$(echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}')"

    if [[ -z "$service_user" ]]; then
        service_user="$(nginx -V 2>&1 | grep -o -- '--user=[^ ]*' | cut -d= -f2)"
        [[ -z "$service_user" ]] && service_user="nobody"
    fi

    service_group="$(getent passwd "$service_user" | cut -d: -f4 \
        | xargs -I{} getent group {} | cut -d: -f1)"

    if [[ -z "$service_group" ]]; then
        service_group="$(nginx -V 2>&1 | grep -o -- '--group=[^ ]*' | cut -d= -f2)"
        [[ -z "$service_group" ]] && service_group="$service_user"
    fi

    # -------- Directory Checks --------
    if [[ ! -d "$working_dir" ]]; then
        errors+="  - Directory not found: $working_dir\n"
    else
        local owner group perm
        owner="$(stat -L -c "%U" "$working_dir" 2>/dev/null)"
        group="$(stat -L -c "%G" "$working_dir" 2>/dev/null)"
        perm="$(stat -L -c "%a" "$working_dir" 2>/dev/null)"

        if [[ "$owner" != "root" ]]; then
            errors+="  - Owner mismatch: $owner (expected root)\n"
        fi

        if [[ "$group" != "$service_group" ]]; then
            errors+="  - Group mismatch: $group (expected $service_group)\n"
        fi

        if find "$working_dir" -maxdepth 0 -perm /0022 | grep -q .; then
            errors+="  - Permissions too broad (mode: $perm, expected <= 750)\n"
        fi

        # -------- Location Check --------
        local doc_root
        while read -r doc_root; do
            [[ -z "$doc_root" ]] && continue

            if [[ "$working_dir" == "$doc_root"* ]]; then
                errors+="  - Directory located inside web document root ($doc_root)\n"
                break
            fi
        done < <(echo "$config" | awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*(root|alias)[[:space:]]+/ {
                gsub(";", "", $2)
                print $2
            }
        ' | sort -u)
    fi

    # -------- Final Reporting --------
    if [[ -z "$errors" ]]; then
        return 0
    fi

    echo -e "MANUAL: core dump directory review required:\n${errors%\\n}\n\
  Remediation Guidance:\n\
  - Remove the 'working_directory' directive if not required.\n\
  - Ensure directory is outside the web document root.\n\
  - Set ownership:\n\
      chown root:$service_group $working_dir\n\
  - Restrict permissions:\n\
      chmod 750 $working_dir"

    return 0
}

remediate_core_dump_directory() {
    return 1
}