#!/usr/bin/env bash

# CIS 3.6 – Ensure access logs are sent to a remote syslog server
# Verifies:
#   - access_log directive is configured to use syslog
# Automation Level: Manual

check_remote_access_syslog() {
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
    # Filter out comments and look for the syslog access_log directive
    if ! grep -Evi '^[[:space:]]*#' <<< "$config" \
        | grep -Eqi '^[[:space:]]*error_log[[:space:]]+syslog:server='; then
        
        errors+="  - No 'access_log' directive configured to send logs to a remote syslog server.\n"
    fi

    # -------- Output Reporting --------
    # If errors exist, append the manual guidance and echo it for run_control to capture
    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - To enable central logging for your access logs, add the below line to your server block.\n"
        errors+="  - Example configuration:\n"
        errors+="      access_log syslog:server=<YOUR_SYSLOG_SERVER_IP>,facility=local7,tag=nginx,severity=info combined;\n"
        errors+="  - Replace <YOUR_SYSLOG_SERVER_IP> with the location of your central log server.\n"
        errors+="  - The local logging facility ('local7') may be changed to any unconfigured facility on your server."

        # Echo without trailing newline to keep the wrapper formatting clean
        echo -e "${errors%\\n}"
    fi
}

remediate_remote_access_syslog() {
    # This control requires manual remediation.
    # Automatically modifying access_log destinations could break:
    #   - SIEM ingestion pipelines
    #   - log retention policies
    #   - centralized logging infrastructure
    
    return 1
}