#!/bin/bash

# CIS 5.X.X – Ensure client_body_timeout and client_header_timeout Are Set to 10
# Verifies:
#   - client_body_timeout is explicitly set to 10.
#   - client_header_timeout is explicitly set to 10.
# Automation Level: Automated
# Notes:
#   - Explicit configuration required (do not rely on defaults).
#   - Values greater than 10 may increase exposure to slow client attacks.
# Remediation Example:
#   client_body_timeout   10;
#   client_header_timeout 10;

check_client_timeouts() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit client timeouts (nginx -T unavailable)"
        return
    fi

    local config body_timeout header_timeout

    config=$(nginx -T 2>/dev/null)

    body_timeout=$(echo "$config" | \
        grep -Poi '^\h*client_body_timeout\h+\K[0-9]+' | head -n1)

    header_timeout=$(echo "$config" | \
        grep -Poi '^\h*client_header_timeout\h+\K[0-9]+' | head -n1)

    if [ -z "$body_timeout" ]; then
        fail "client_body_timeout not configured"
        return
    fi

    if [ -z "$header_timeout" ]; then
        fail "client_header_timeout not configured"
        return
    fi

    if [ "$body_timeout" -ne 10 ]; then
        fail "client_body_timeout set to $body_timeout (expected 10)"
        return
    fi

    if [ "$header_timeout" -ne 10 ]; then
        fail "client_header_timeout set to $header_timeout (expected 10)"
        return
    fi

    pass "client timeouts properly configured (10 seconds)"
}
