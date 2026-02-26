#!/bin/bash

# CIS 3.6 – Ensure access logs are sent to a remote syslog server
# Verifies:
#   - access_log directive is configured to use syslog
# Automation Level: Manual Remediation

check_remote_access_syslog() {
    if ! nginx -T >/dev/null 2>&1; then
        fail "nginx configuration dump failed"
        return
    fi

    local config compliant=0
    config="$(nginx -T 2>/dev/null)"
    
    # Extract the regex into a variable to avoid Bash parsing errors with the semicolon
    local re_syslog='^[[:space:]]*access_log[[:space:]]+syslog:server=[^;]+;'

    while IFS= read -r line; do
        # Skip commented lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ $re_syslog ]]; then
            compliant=1
            break
        fi
    done <<< "$config"

    if [[ "$compliant" -eq 1 ]]; then
        pass "Access logs are sent to a remote syslog server"
        return
    else
        fail "Access logs are NOT sent to a remote syslog server"
        manual_remediation_access_syslog
    fi
}

manual_remediation_access_syslog() {
    echo ""
    echo "======================================================================"
    echo " MANUAL REMEDIATION REQUIRED: CIS 3.6 (Remote Syslog Access Logging)  "
    echo "======================================================================"
    echo "Your Nginx configuration does not currently send access logs to a remote"
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
    echo "   access_log syslog:server=<YOUR_SYSLOG_SERVER_IP>,facility=local7,tag=nginx,severity=info combined;"
    echo ""
    echo "   * Note 1: Replace <YOUR_SYSLOG_SERVER_IP> with the actual IP address"
    echo "     or hostname of your central log server (e.g., 192.168.2.1)."
    echo "   * Note 2: The local logging facility ('local7') may be changed to any"
    echo "     unconfigured facility on your server."
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
# check_remote_access_syslog