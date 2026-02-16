#!/bin/bash

# CIS 4.X.X – Ensure Weak Ciphers Are Disabled
# Verifies:
#   - ssl_ciphers directive exists.
#   - Weak cipher exclusions are explicitly present.
# Automation Level: Partial
# Notes:
#   - This verifies exclusion patterns (!EXP, !NULL, !MD5, etc.).
#   - Does not expand OpenSSL cipher macros.
#   - TLS 1.3 cipher suites are not controlled by ssl_ciphers.
# Remediation Example:
#   ssl_ciphers ALL:!EXP:!NULL:!ADH:!LOW:!SSLv2:!SSLv3:!MD5:!RC4;

check_weak_ciphers_disabled() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit ssl_ciphers (nginx -T unavailable)"
        return
    fi

    local config ciphers

    config=$(nginx -T 2>/dev/null)

    ciphers=$(echo "$config" | \
        grep -Poi '^\h*ssl_ciphers\h+\K[^;]+' | head -n1)

    if [ -z "$ciphers" ]; then
        fail "ssl_ciphers directive missing (for disabling weak ciphers)"
        return
    fi

    # Required exclusion patterns
    local required_exclusions="!EXP !NULL !ADH !LOW !SSLv2 !SSLv3 !MD5 !RC4"

    for pattern in $required_exclusions; do
        if ! echo "$ciphers" | grep -q "$pattern"; then
            fail "ssl_ciphers missing required exclusion: $pattern"
            return
        fi
    done

    pass "Weak cipher exclusions properly configured"
}
