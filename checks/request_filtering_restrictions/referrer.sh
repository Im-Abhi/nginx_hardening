#!/usr/bin/env bash

# CIS 5.3.4 – Ensure the Referrer Policy is enabled and configured properly
# Automation Level: Manual

check_referrer_policy() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local findings=""
    local has_header=0

    # Official W3C Referrer-Policy values (uppercased for comparison)
    local valid_policies=(
        "NO-REFERRER"
        "NO-REFERRER-WHEN-DOWNGRADE"
        "ORIGIN"
        "ORIGIN-WHEN-CROSS-ORIGIN"
        "SAME-ORIGIN"
        "STRICT-ORIGIN"
        "STRICT-ORIGIN-WHEN-CROSS-ORIGIN"
        "UNSAFE-URL"
    )

    while read -r file line val; do
        has_header=1

        local val_upper="${val^^}"

        val_upper="$(awk '{$1=$1; print}' <<< "$val_upper")"

        local has_always=0
        local policy="$val_upper"

        if [[ "$val_upper" =~ (^|[[:space:]])ALWAYS($|[[:space:]]) ]]; then
            has_always=1
            policy="${val_upper% ALWAYS}"
        fi

        if [[ "$has_always" -eq 0 ]]; then
            findings+="  - [ERROR] Referrer-Policy in $file (line $line) is missing the 'always' parameter.\n"
        fi

        local is_valid=0
        for valid_policy in "${valid_policies[@]}"; do
            if [[ "$policy" == "$valid_policy" ]]; then
                is_valid=1
                break
            fi
        done

        if [[ "$is_valid" -eq 0 ]]; then
            findings+="  - [ERROR] Referrer-Policy in $file (line $line) has an unrecognized or malformed policy: '$val'\n"
            continue
        fi

        if [[ "$policy" == "UNSAFE-URL" ]]; then
            findings+="  - [ERROR] Referrer-Policy in $file (line $line) is set to 'unsafe-url', which leaks full URLs and query strings.\n"
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*add_header[[:space:]]+/ {
            line_val=$0
            sub(/^[[:space:]]*add_header[[:space:]]+/, "", line_val)
            sub(/;[[:space:]]*$/, "", line_val)

            # Match Referrer-Policy (case-insensitive, optional quotes)
            if (match(line_val, /^["\047]?[Rr][Ee][Ff][Ee][Rr][Rr][Ee][Rr]-[Pp][Oo][Ll][Ii][Cc][Yy]["\047]?[[:space:]]+/)) {
                val = substr(line_val, RLENGTH + 1)
                gsub(/["\047]/, "", val)
                print file, line, val
            }
        }
    ')

    if [[ "$has_header" -eq 0 ]]; then
        findings+="  - [ERROR] 'Referrer-Policy' header is not configured.\n"
    fi

    if [[ -n "$findings" ]]; then
        findings="MANUAL: ${findings}"
        findings+="\n  Remediation Guidance:\n"
        findings+="  - Configure the Referrer-Policy header to control how much origin information is sent with requests.\n"
        findings+="  - Choose a policy that balances privacy with your application's analytics and routing requirements.\n"
        findings+="  - Recommended modern baseline (Add to 'http' or 'server' block):\n"
        findings+="      add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;"

        echo -e "${findings%\\n}"
        return 1
    fi

    return 0
}

remediate_referrer_policy() {
    # Blindly injecting a strict Referrer-Policy can break
    # internal routing, SSO flows, and analytics behavior.
    return 1
}