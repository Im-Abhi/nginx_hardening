#!/bin/bash

# CIS 4.X.X – Ensure ssl_session_tickets is Disabled
# Verifies:
#   - ssl_session_tickets is explicitly set to off in the effective nginx configuration.
# Automation Level: Automated
# Notes:
#   - If directive is missing, nginx default may be 'on' (version dependent).
#   - CIS requires explicit disabling.
# Remediation Example:
#   ssl_session_tickets off;

check_ssl_session_tickets_disabled() {

    # Ensure effective configuration can be inspected
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit ssl_session_tickets (nginx -T unavailable)"
        return
    fi

    local tickets_on tickets_off

    tickets_on=$(nginx -T 2>/dev/null | \
        grep -Pi '^\h*ssl_session_tickets\h+on\b')

    tickets_off=$(nginx -T 2>/dev/null | \
        grep -Pi '^\h*ssl_session_tickets\h+off\b')

    if [ -n "$tickets_on" ]; then
        fail "ssl_session_tickets explicitly enabled"
        return
    fi

    if [ -z "$tickets_off" ]; then
        fail "ssl_session_tickets not explicitly disabled"
        return
    fi

    pass "ssl_session_tickets explicitly disabled"
}
