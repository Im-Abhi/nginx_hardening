#!/bin/bash

# CIS 3.5 – Ensure error logs are sent to a remote syslog server
# Verifies:
#   - error_log directive is configured to use syslog
# Automation Level: Manual Remediation

check_remote_syslog() {
    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local config compliant=0
    config="$(nginx -T 2>/dev/null)"
    
    # Regex to catch an error_log directive pointing to a syslog server
    local re_syslog='^[[:space:]]*error_log[[:space:]]+syslog:server=[^;]+;'

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ $re_syslog ]]; then
            compliant=1
            break
        fi
    done <<< "$config"

    if [[ "$compliant" -eq 1 ]]; then
        pass "Error logs are sent to a remote syslog server"
        return
    else
        fail "Error logs are NOT sent to a remote syslog server"
        manual_remediation_syslog
    fi
}

manual_remediation_syslog() {
    echo ""
    echo "======================================================================"
    echo " MANUAL REMEDIATION REQUIRED: CIS 3.5 (Remote Syslog Error Logging)   "
    echo "======================================================================"
    echo "Your Nginx configuration does not currently send error logs to a remote "
    echo "syslog server."
    echo ""
    echo "To fix this manually, follow these steps:"
    echo ""
    echo "1. Open your primary Nginx configuration file. This is usually located at:"
    echo "   /etc/nginx/nginx.conf"
    echo "   (or inside your specific site config under /etc/nginx/conf.d/)"
    echo ""
    echo "2. Inside the 'http' or 'server' block, add the following line:"
    echo ""
    echo "   error_log syslog:server=<YOUR_SYSLOG_SERVER_IP> info;"
    echo ""
    echo "   * Note: Replace <YOUR_SYSLOG_SERVER_IP> with the actual IP address"
    echo "     or hostname of your central log server (e.g., 192.168.2.1)."
    echo ""
    echo "3. Test the configuration for syntax errors:"
    echo "   nginx -t"
    echo ""
    echo "4. If the test is successful, reload Nginx to apply the changes:"
    echo "   nginx -s reload"
    echo "======================================================================"
    echo ""
}

# Uncomment below to run directly
# check_remote_syslog