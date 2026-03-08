#!/usr/bin/env bash

# CIS 3.5 – Ensure error logs are sent to a remote syslog server
# Verifies:
#   - error_log directive is configured to use syslog
# Automation Level: Manual

check_remote_syslog() {
    local config
    local errors=""

    # -------- Prerequisite Check --------
    if ! command -v nginx >/dev/null 2>&1; then
        echo "  - nginx binary not found."
        return
    fi

    if ! config="$(nginx -T 2>/dev/null)"; then
        echo "  - Nginx configuration dump failed."
        return
    fi

    # -------- Detection Logic --------
    # Filter out comments and look for the syslog error_log directive
    if ! echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | grep -Eqi '^[[:space:]]*error_log[[:space:]]+syslog:server='; then
        
        errors+="  - No 'error_log' directive configured to send logs to a remote syslog server.\n"
    fi

    # -------- Output Reporting --------
    # If errors exist, append the manual guidance and echo it for run_control to capture
    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Configure NGINX to send error logs to a remote syslog server.\n"
        errors+="  - Example configuration inside the 'http' or 'server' block:\n"
        errors+="      error_log syslog:server=<YOUR_SYSLOG_SERVER_IP> info;\n"
        errors+="  - Replace <YOUR_SYSLOG_SERVER_IP> with the actual IP address or hostname of your central log server (e.g., 192.168.2.1)."

        # Echo without trailing newline to keep the wrapper formatting clean
        echo -e "${errors%\\n}"
    fi
}

remediate_remote_syslog() {
    # This control requires manual remediation.
    # Automatically modifying error_log destinations could break:
    #   - SIEM ingestion pipelines
    #   - log retention policies
    #   - centralized logging infrastructure
    
    return 1
}