#!/usr/bin/env bash

# CIS 5.2.4 – Ensure the number of connections per IP address is limited
# Automation Level: Manual (SAFE MODE: Auto-remediation disabled)

check_limit_conn() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    if ! nginx -T >/dev/null 2>&1; then
        echo "Failed to parse nginx configuration (nginx -T error)"
        return 1
    fi

    local errors=""
    local has_zone=0
    local has_limit=0
    local zone_names=()
    local limit_refs=()

    while read -r type file line val; do

        if [[ "$type" == "zone" ]]; then
            has_zone=1

            # Extract first token (key variable) and zone name
            local key_var zone_name
            key_var="${val%% *}"

            if [[ "$val" =~ zone=([^:;[:space:]]+) ]]; then
                zone_name="${BASH_REMATCH[1]}"
                zone_names+=("$zone_name")
            fi

            if [[ "$key_var" != "\$binary_remote_addr" && "$key_var" != "\$remote_addr" ]]; then
                errors+="  - [WARNING] limit_conn_zone in $file (line $line) does not track client IPs (found: $key_var).\n"
            fi

        elif [[ "$type" == "limit" ]]; then
            has_limit=1

            local zone_ref
            zone_ref="${val%% *}"
            limit_refs+=("$zone_ref")
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        $1 == "limit_conn_zone" {
            val=$0
            sub(/^[[:space:]]*limit_conn_zone[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print "zone", file, line, val
        }

        $1 == "limit_conn" {
            val=$0
            sub(/^[[:space:]]*limit_conn[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print "limit", file, line, val
        }
    ')

    if [[ "$has_zone" -eq 0 ]]; then
        errors+="  - 'limit_conn_zone' directive is missing (shared memory zone not defined).\n"
    fi

    if [[ "$has_limit" -eq 0 ]]; then
        errors+="  - 'limit_conn' directive is missing (connection limit is not actively enforced).\n"
    fi

    # Validate that limit_conn references a declared zone
    if [[ "$has_zone" -eq 1 && "$has_limit" -eq 1 ]]; then
        local ref found
        for ref in "${limit_refs[@]}"; do
            found=0
            for zn in "${zone_names[@]}"; do
                [[ "$ref" == "$zn" ]] && found=1 && break
            done
            if [[ "$found" -eq 0 ]]; then
                errors+="  - limit_conn references undeclared zone '$ref'.\n"
            fi
        done
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Define a shared memory zone in the 'http' block:\n"
        errors+="      limit_conn_zone \$binary_remote_addr zone=limitperip:10m;\n"
        errors+="  - Apply the limit in the relevant 'server' or 'location' block:\n"
        errors+="      limit_conn limitperip 10;\n"
        errors+="  - IMPORTANT: Tune the value to your application's real traffic profile to avoid 503 errors."

        echo -e "${errors%\\n}"
        return 1
    fi

    return 0
}

remediate_limit_conn() {

    # Intentionally manual:
    # Blindly applying connection limits can block legitimate traffic,
    # especially behind NAT, load balancers, or shared IPs.

    return 1
}