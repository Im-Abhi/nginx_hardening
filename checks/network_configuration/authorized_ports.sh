#!/usr/bin/env bash

# CIS 2.4.1 – Ensure NGINX only listens on authorized ports
# Automation Level: Manual

check_listen_ports() {
    local authorized_ports_str="${NGINX_AUTHORIZED_PORTS:-80 443}"
    local -a authorized_ports=($authorized_ports_str)

    local findings=""
    local current_file=""
    local line_number=0
    local line
    local listen_re='^[[:space:]]*listen[[:space:]]+(.+)[[:space:]]*;[[:space:]]*$'

    # -------- Prerequisite --------
    if ! nginx -t >/dev/null 2>&1; then
        echo "MANUAL: nginx configuration invalid"
        return 0
    fi

    # -------- Parse live expanded config --------
    while IFS= read -r line; do
        # Track file context from nginx -T output
        if [[ "$line" =~ ^#\ configuration\ file\ (.*):$ ]]; then
            current_file="${BASH_REMATCH[1]}"
            line_number=0
            continue
        fi

        ((line_number++))

        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue

        # Match listen directives safely
        if [[ "$line" =~ $listen_re ]]; then
            local listen_args="${BASH_REMATCH[1]}"
            local port=""
            local is_authorized=0
            local clean_line

            clean_line="$(echo "$line" | sed 's/^[[:space:]]*//')"

            # Skip unix domain sockets
            [[ "$listen_args" =~ unix: ]] && continue

            # Case 1: explicit :port (IPv4, hostname, *, IPv6 in brackets)
            if [[ "$listen_args" =~ :([0-9]{1,5})([[:space:]]|$) ]]; then
                port="${BASH_REMATCH[1]}"

            # Case 2: bare numeric port
            elif [[ "$listen_args" =~ ^[[:space:]]*([0-9]{1,5})([[:space:]]|$) ]]; then
                port="${BASH_REMATCH[1]}"
            fi

            # Skip if no numeric port extracted
            [[ -z "$port" ]] && continue

            # Validate port range
            if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
                findings+="  - Invalid listen port detected | File: ${current_file:-unknown} | Line: $line_number | $clean_line"$'\n'
                continue
            fi

            # Check against authorized list
            for allowed in "${authorized_ports[@]}"; do
                if [[ "$port" == "$allowed" ]]; then
                    is_authorized=1
                    break
                fi
            done

            if (( is_authorized == 0 )); then
                findings+="  - Unauthorized Port: $port | File: ${current_file:-unknown} | Line: $line_number | $clean_line"$'\n'
            fi
        fi
    done < <(nginx -T 2>/dev/null)

    # -------- Final Reporting --------
    if [[ -z "$findings" ]]; then
        return 0
    fi

    echo -e "MANUAL: unauthorized listen ports detected:\n${findings%$'\n'}\n\
  Remediation Guidance:\n\
  - Review the unauthorized ports detected above.\n\
  - If the port is NOT authorized, remove or correct the associated 'listen' directive.\n\
  - If the port IS authorized for this environment, define it before running the audit:\n\
      export NGINX_AUTHORIZED_PORTS=\"80 443 8080\""

    return 0
}

remediate_listen_ports() {
    return 1
}
