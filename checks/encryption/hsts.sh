#!/bin/bash

# CIS 4.X.X – Ensure HSTS is Configured
# Verifies:
#   - add_header Strict-Transport-Security is present
#   - max-age is >= 15768000 seconds (6 months)
# Automation Level: Partial
# Notes:
#   - This verifies configuration only.
#   - Does not validate runtime header delivery (e.g., HTTPS-only responses).
#   - HSTS should only be enabled on HTTPS-enabled servers.
# Remediation Example:
#   add_header Strict-Transport-Security "max-age=15768000;" always;

check_hsts_configuration() {

    # Ensure effective config is available
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit HSTS (nginx -T unavailable)"
        return
    fi

    local hsts_line max_age

    # Extract HSTS directive line
    hsts_line=$(nginx -T 2>/dev/null | \
        grep -Pi '^\h*add_header\h+Strict-Transport-Security\b' | head -n1)

    if [ -z "$hsts_line" ]; then
        fail "HSTS header not configured"
        return
    fi

    # Extract max-age value
    max_age=$(echo "$hsts_line" | grep -Poi 'max-age=\K[0-9]+')

    if [ -z "$max_age" ]; then
        fail "HSTS configured but max-age not specified"
        return
    fi

    if [ "$max_age" -lt 15768000 ]; then
        fail "HSTS max-age too low (${max_age}s, must be >= 15768000s)"
        return
    fi

    pass "HSTS configured with max-age=${max_age}s"
}
