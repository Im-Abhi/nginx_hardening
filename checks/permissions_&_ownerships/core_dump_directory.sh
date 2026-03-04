#!/usr/bin/env bash

# CIS 2.3.4 – Ensure the core dump directory is secured
# Automation Level: Manual

check_core_dump_directory() {

    local config working_dir
    local service_user service_group
    local errors=""

    # -------- Prerequisite --------
    if ! nginx -t >/dev/null 2>&1; then
        manual "2.3.4 nginx configuration invalid"
        return
    fi

    config="$(nginx -T 2>/dev/null)"

    # -------- Extract working_directory --------
    working_dir=$(echo "$config" | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*working_directory[[:space:]]+/ {
            gsub(";", "", $2)
            print $2
            exit
        }
    ')

    if [[ -z "$working_dir" ]]; then
        pass "2.3.4 working_directory directive not configured (compliant by default)"
        return
    fi

    # -------- Extract Service Account (Strictly Dynamic) --------
    # 1. Try config file first
    service_user=$(echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}')
    
    # 2. Fallback to compile-time user parameter
    if [[ -z "$service_user" ]]; then
        service_user=$(nginx -V 2>&1 | grep -o -- '--user=[^ ]*' | cut -d= -f2)
        [[ -z "$service_user" ]] && service_user="nobody" # NGINX ultimate fallback
    fi

    # 3. Resolve group via OS lookup, fallback to compile-time group parameter
    service_group=$(getent passwd "$service_user" | cut -d: -f4 \
        | xargs -I{} getent group {} | cut -d: -f1)
    
    if [[ -z "$service_group" ]]; then
        service_group=$(nginx -V 2>&1 | grep -o -- '--group=[^ ]*' | cut -d= -f2)
        [[ -z "$service_group" ]] && service_group="$service_user"
    fi

    # -------- Directory Existence --------
    if [[ ! -d "$working_dir" ]]; then
        errors+="  - Directory not found: $working_dir\n"
    else
        local owner group perm
        owner=$(stat -L -c "%U" "$working_dir" 2>/dev/null)
        group=$(stat -L -c "%G" "$working_dir" 2>/dev/null)
        perm=$(stat -L -c "%a" "$working_dir" 2>/dev/null)

        # -------- Ownership Checks --------
        if [[ "$owner" != "root" ]]; then
            errors+="  - Owner mismatch: $owner (expected root)\n"
        fi

        if [[ "$group" != "$service_group" ]]; then
            errors+="  - Group mismatch: $group (expected $service_group)\n"
        fi

        # -------- Permission Checks --------
        if find "$working_dir" -maxdepth 0 -perm /0022; then
            errors+="  - Directory permissions are too broad (mode: $perm, expected <= 750)\n"
        fi

        # -------- Location Check (Strictly Dynamic) --------
        local doc_root
        local in_doc_root=0
        
        # Loop through every unique root/alias defined anywhere in the config
        while read -r doc_root; do
            [[ -z "$doc_root" ]] && continue
            
            # Check if the working directory falls anywhere inside this specific web root
            if [[ "$working_dir" == "$doc_root"* ]]; then
                in_doc_root=1
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
        pass "2.3.4 core dump directory '$working_dir' is compliant"
    else
        local remediation=""
        remediation+="\n  Remediation Guidance:\n"
        remediation+="  - Remove the 'working_directory' directive if not required.\n"
        remediation+="  - Ensure directory is outside the web document root.\n"
        remediation+="  - Set correct ownership:\n"
        remediation+="      chown root:$service_group $working_dir\n"
        remediation+="  - Restrict permissions:\n"
        remediation+="      chmod 750 $working_dir\n"

        manual "2.3.4 core dump directory review required:\n${errors%\\n}${remediation}"
    fi
}