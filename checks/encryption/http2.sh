#!/bin/bash

# CIS 4.X.X – Ensure HTTP/2 is Enabled on HTTPS Listeners
# Verifies:
#   - HTTPS listeners exist.
#   - HTTP/2 is enabled either via:
#       listen 443 ssl http2;
#       OR
#       http2 on;
# Automation Level: Partial
# Notes:
#   - Does not validate runtime ALPN negotiation.
#   - Redirect-only port 80 listeners are ignored.
# Remediation Example:
#   listen 443 ssl http2;
#   OR
#   http2 on;

check_http2_enabled() {

    # Ensure effective configuration can be inspected
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit HTTP/2 (nginx -T unavailable)"
        return
    fi

    local config https_listeners http2_listen http2_directive

    config=$(nginx -T 2>/dev/null)

    # Detect HTTPS listeners
    https_listeners=$(echo "$config" | \
        grep -Pi '^\h*listen\h+.*443.*ssl')

    if [ -z "$https_listeners" ]; then
        fail "no HTTPS listeners detected"
        return
    fi

    # Detect HTTP/2 via listen directive
    http2_listen=$(echo "$config" | \
        grep -Pi '^\h*listen\h+.*443.*ssl.*http2')

    # Detect HTTP/2 via new directive style
    http2_directive=$(echo "$config" | \
        grep -Pi '^\h*http2\h+on\b')

    if [ -n "$http2_listen" ] || [ -n "$http2_directive" ]; then
        pass "HTTP/2 enabled on HTTPS listeners"
    else
        fail "HTTPS listeners detected but HTTP/2 not enabled"
    fi
}
