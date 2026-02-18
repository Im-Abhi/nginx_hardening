#!/bin/bash

# CIS X.X.X – Verify IP-Based Restrictions Are Configured Correctly
# Verifies:
#   - Presence of allow/deny directives within location blocks.
#   - Detects if 'deny all;' is used with allow rules.
# Automation Level: Manual (Partially Automatable)
# Notes:
#   - This control requires human validation.
#   - Must confirm allowed IPs are appropriate for environment.
#   - Cannot determine if CIDR ranges are overly permissive.
# Suggested Remediation Example:
#   location / {
#       allow 10.1.1.1;
#       deny all;
#   }

check_ip_based_restrictions() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit IP restrictions (nginx -T unavailable)"
        return
    fi

    local config allow_rules deny_all

    config=$(nginx -T 2>/dev/null)

    allow_rules=$(echo "$config" | grep -Pi '^\h*allow\h+')
    deny_all=$(echo "$config" | grep -Pi '^\h*deny\h+all\b')

    if [ -z "$allow_rules" ]; then
        echo "[MANUAL REVIEW REQUIRED]"
        echo "No allow directives found in configuration."
        echo "If IP-based restrictions are required, verify they are implemented."
        return
    fi

    echo "[MANUAL REVIEW REQUIRED]"
    echo "Detected allow/deny rules:"
    echo "----------------------------------"
    echo "$allow_rules"
    echo "$deny_all"
    echo "----------------------------------"
    echo "Ensure:"
    echo " - Allowed IPs are not overly broad (e.g., 0.0.0.0/0)."
    echo " - CIDR ranges are appropriate."
    echo " - 'deny all;' is used where necessary."

}
