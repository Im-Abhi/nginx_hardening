#!/usr/bin/env bash

# CIS 5.1.1 – Ensure allow and deny filters limit access to specific IP addresses
# Automation Level: Manual (Requires human review of network ranges)

check_ip_based_restrictions() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    # Ensure nginx config is valid before parsing
    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local errors=""
    local has_allow_all=0
    local block_has_allow=()
    local block_has_deny_all=()
    local formatted_rules=()
    local rules_raw=()

    contains() {
        local seeking="$1"; shift
        local item
        for item in "$@"; do
            [[ "$item" == "$seeking" ]] && return 0
        done
        return 1
    }

    # Capture rules safely
    while IFS= read -r line; do
        [[ -n "$line" ]] && rules_raw+=("$line")
    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; ctx="global"; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        # Approximate context tracking (heuristic, not full parser)
        /^[[:space:]]*(http|server|location)[[:space:]\{]/ {
            ctx=$0
            sub(/\{.*$/, "", ctx)
            sub(/^[[:space:]]*/, "", ctx)
            sub(/[[:space:]]+$/, "", ctx)
        }

        /^[[:space:]]*(allow|deny)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(allow|deny)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file "|" line "|" type "|" val "|" ctx
        }
    ')

    if [[ ${#rules_raw[@]} -eq 0 ]]; then
        errors+="  - No IP-based access restrictions (allow/deny) found in NGINX configuration.\n"
        errors+="    If this server hosts sensitive or internal endpoints, IP restrictions should be implemented.\n"
    else
        errors+="  - IP restrictions found. Please verify correctness:\n"

        local block_id
        for entry in "${rules_raw[@]}"; do
            IFS='|' read -r file line type val context <<< "$entry"

            formatted_rules+=("      - [INFO] $type $val; (context: '$context (approx)' | file: $file | line: $line)")

            # Detect allow all
            if [[ "$type" == "allow" && "$val" == "all" ]]; then
                has_allow_all=1
            fi

            # Detect overly broad CIDR
            if [[ "$type" == "allow" ]]; then
                if [[ "$val" == "0.0.0.0/0" || "$val" == "0.0.0.0/8" ]]; then
                    errors+="  - [WARNING] Overly broad CIDR '$val' detected → effectively public access\n"
                fi
            fi

            # Block-level tracking
            block_id="${file}::${context}"

            if [[ "$type" == "allow" && "$val" != "all" ]]; then
                contains "$block_id" "${block_has_allow[@]}" || block_has_allow+=("$block_id")
            fi

            if [[ "$type" == "deny" && "$val" == "all" ]]; then
                contains "$block_id" "${block_has_deny_all[@]}" || block_has_deny_all+=("$block_id")
            fi
        done

        # Print rules
        local rule
        for rule in "${formatted_rules[@]}"; do
            errors+="$rule\n"
        done

        # Warn allow all
        if [[ "$has_allow_all" -eq 1 ]]; then
            errors+="  - [WARNING] 'allow all;' was found. This defeats IP restrictions for that block.\n"
        fi

        # Warn missing deny all
        local b_id
        for b_id in "${block_has_allow[@]}"; do
            if ! contains "$b_id" "${block_has_deny_all[@]}"; then
                local ctx_str="${b_id#*::}"
                errors+="  - [WARNING] The context '$ctx_str' has 'allow' rules but is missing a 'deny all;' fallback.\n"
            fi
        done
    fi

    # Output results
    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Compile a list of trusted IP addresses or network ranges.\n"
        errors+="  - Implement allow/deny rules in 'server' or 'location' blocks.\n"
        errors+="  - Ensure restricted blocks explicitly end with 'deny all;'\n"
        errors+="  - Example:\n"
        errors+="      location /admin/ {\n"
        errors+="          allow 10.1.1.0/24;\n"
        errors+="          deny all;\n"
        errors+="      }"

        echo -e "${errors%\\n}"
    fi
}

remediate_ip_based_restrictions() {
    # Manual-only control (per CIS guidance)
    # Auto-remediation could break production traffic

    return 1
}