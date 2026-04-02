#!/usr/bin/env bash

# CIS 5.2.4 – Ensure the number of connections per IP address is limited
# Automation Level: Manual (SAFE MODE: Auto-remediation disabled to prevent 503 DoS)

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
    local zones_declared=()
    local limits_applied=()

    # 1. Parse configuration in a single pass
    while read -r type file line val; do
        
        if [[ "$type" == "zone" ]]; then
            has_zone=1
            # Verify the zone is actually tracking the IP address
            if ! [[ "$val" =~ \$binary_remote_addr ]] && ! [[ "$val" =~ \$remote_addr ]]; then
                errors+="  - [WARNING] limit_conn_zone in $file (line $line) does not appear to track IP addresses (\$binary_remote_addr).\n"
            fi
            zones_declared+=("$val")
            
        elif [[ "$type" == "limit" ]]; then
            has_limit=1
            limits_applied+=("Found in $file (line $line): limit_conn $val;")
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*limit_conn_zone[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*limit_conn_zone[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print "zone", file, line, val
        }

        /^[[:space:]]*limit_conn[[:space:]]+/ {
            val=$0
            sub(/^[[:space:]]*limit_conn[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print "limit", file, line, val
        }
    ')

    # 2. Evaluate State
    if [[ "$has_zone" -eq 0 ]]; then
        errors+="  - 'limit_conn_zone' directive is missing (Shared memory zone not defined).\n"
    fi

    if [[ "$has_limit" -eq 0 ]]; then
        errors+="  - 'limit_conn' directive is missing (Connection limit is not actively enforced).\n"
    fi

    # 3. Output results and return 1 for wrapper framework compatibility
    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Ensure connection limits are configured to mitigate DoS/DDoS attacks.\n"
        errors+="  - Define the memory zone in your 'http' block:\n"
        errors+="      limit_conn_zone \$binary_remote_addr zone=limitperip:10m;\n"
        errors+="  - Enforce the limit in the appropriate 'server' or 'location' block:\n"
        errors+="      limit_conn limitperip 10;"
        
        echo -e "${errors%\\n}"
        return 1
    fi

    # SUCCESS: Exiting completely silently
    return 0
}

remediate_limit_conn() {

    # SAFE MODE: Auto-remediation intentionally aborted.
    # Blindly injecting a limit_conn value (e.g., 10) can instantly break applications, 
    # block legitimate NAT/Corporate IP traffic, and cause 503 Service Unavailable errors.
    
    # echo "[WARNING] CIS 5.2.4 requires application-specific traffic tuning."
    # echo "SAFE MODE: Auto-remediation aborted to prevent accidental DoS/503 errors. Please apply connection limits manually."
    
    return 1
}