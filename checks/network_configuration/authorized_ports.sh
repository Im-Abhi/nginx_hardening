#!/usr/bin/env bash

# CIS 2.4.1 – Ensure NGINX only listens on authorized ports
# Automation Level: Manual

check_listen_ports() {
    # Dynamically allow environment overrides, default to 80 and 443
    local authorized_ports_str="${NGINX_AUTHORIZED_PORTS:-80 443}"
    local -a authorized_ports=($authorized_ports_str)
    
    local errors=""
    local current_file=""
    local line_number=0

    # -------- Prerequisite --------
    if ! nginx -t >/dev/null 2>&1; then
        manual "2.4.1 nginx configuration invalid"
        return
    fi

    # -------- Parse Configuration --------
    # Loop over the live config dump to evaluate every included file natively
    while IFS= read -r line; do
        # Track the current file context from the nginx -T headers
        if [[ "$line" =~ ^#\ configuration\ file\ (.*):$ ]]; then
            current_file="${BASH_REMATCH[1]}"
            line_number=0
            continue
        fi

        ((line_number++))

        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Detect listen directives
        if [[ "$line" =~ ^[[:space:]]*listen[[:space:]]+ ]]; then
            
            # Skip unix domain sockets
            [[ "$line" =~ unix: ]] && continue

            # Extract the port (handles standard, IPv4, and IPv6 bracket formats securely)
            local port
            port=$(echo "$line" | grep -oE '[0-9]{2,5}' | head -n1)
            
            if [[ -n "$port" ]]; then
                local is_authorized=0
                
                # Check if extracted port matches any in our allowed array
                for allowed in "${authorized_ports[@]}"; do
                    if [[ "$port" == "$allowed" ]]; then
                        is_authorized=1
                        break
                    fi
                done

                # If unauthorized, log the exact file, line, and config syntax
                if [[ "$is_authorized" -eq 0 ]]; then
                    local clean_line
                    clean_line=$(echo "$line" | sed 's/^[ \t]*//') # Trim leading whitespace
                    errors+="  - Unauthorized Port: $port | File: $current_file | Line: $line_number | $clean_line\n"
                fi
            fi
        fi
    done < <(nginx -T 2>/dev/null)

    # -------- Final Reporting --------
    if [[ -z "$errors" ]]; then
        pass "2.4.1 Only authorized listen ports configured (${authorized_ports[*]})"
    else
        local remediation=""
        remediation+="\n  Remediation Guidance:\n"
        remediation+="  - Review the unauthorized ports detected above.\n"
        remediation+="  - If the port is NOT authorized, comment out or delete the associated 'listen' directive.\n"
        remediation+="  - If the port IS authorized for this specific environment, update the environment variable before running the audit:\n"
        remediation+="      export NGINX_AUTHORIZED_PORTS=\"80 443 8080\"\n"

        manual "2.4.1 Unauthorized listen ports detected:\n${errors%\\n}${remediation}"
    fi
}