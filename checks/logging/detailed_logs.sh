#!/usr/bin/env bash

# CIS 3.1 – Ensure detailed logging is enabled
# Automation Level: Manual (Requires organizational policy review)

check_detailed_logging() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local formats=""

    # AWK state machine to extract multi-line log_format definitions cleanly
    formats=$(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { next }
        /^[[:space:]]*#/ { next }
        
        /^[[:space:]]*log_format[[:space:]]+/ {
            in_log=1
            sub(/^[[:space:]]+/, "", $0) # Strip leading whitespace
            buf=$0
            if (buf ~ /;[[:space:]]*$/) {
                print buf
                in_log=0
            }
            next
        }
        
        in_log {
            sub(/^[[:space:]]+/, "", $0)
            buf = buf " " $0
            if (buf ~ /;[[:space:]]*$/) {
                # Compress multiple spaces into a single space for clean output
                gsub(/[[:space:]]+/, " ", buf)
                print buf
                in_log=0
            }
        }
    ')

    if [[ -z "$formats" ]]; then
        errors+="  - No custom 'log_format' directives found. NGINX is using the compiled-in default.\n"
    else
        errors+="  - Found log_format directives: \n"
        while IFS= read -r line; do
            errors+="      $line\n"
        done <<< "$formats"
    fi

    # Since this relies on organizational policy, we always append the manual guidance
    # so the auditor knows exactly what forensic variables to look for.
    errors+="\n  Remediation Guidance:\n"
    errors+="  - Verify the log formats above meet your organizational security and privacy policies.\n"
    errors+="  - Edit /etc/nginx/nginx.conf to update the 'log_format' directive if needed.\n"
    errors+="  - Highly recommended forensic variables include:\n"
    errors+="      \$server_name, \$time_iso8601, \$remote_addr, \$remote_port,\n"
    errors+="      \$server_addr, \$request, \$status, \$http_user_agent"

    # Print the aggregated data for the run_control engine
    echo -e "${errors%\\n}"
}


remediate_detailed_logging() {

    # This control intentionally requires manual remediation.
    # Automatically modifying log formats is highly dangerous as it can:
    #   1. Break downstream SIEM/Logstash/Splunk parsing rules.
    #   2. Accidentally log sensitive PII (passwords, tokens in URLs) violating GDPR/HIPAA.
    
    # Per the silent remediation framework rule, we do nothing and return 1.
    return 1
}