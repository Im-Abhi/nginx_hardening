#!/bin/bash

# CIS 4.X.X – Ensure Only PFS Ciphers Are Used
# Verifies:
#   - ssl_ciphers and proxy_ssl_ciphers contain only forward secrecy ciphers.
#   - Ensures ECDHE/EECDH or DHE/EDH are used.
#   - Ensures no obvious weak ciphers are present.
# Automation Level: Partial
# Notes:
#   - Full validation depends on OpenSSL cipher expansion.
#   - TLS 1.3 ciphers are not controlled by ssl_ciphers directive.
# Remediation Example:
#   ssl_ciphers EECDH:EDH:!NULL:!SSLv2:!RC4:!aNULL:!3DES:!IDEA;
#   proxy_ssl_ciphers EECDH:EDH:!NULL:!SSLv2:!RC4:!aNULL:!3DES:!IDEA;

check_pfs_ciphers() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit PFS ciphers (nginx -T unavailable)"
        return
    fi

    local config ciphers proxy_ciphers

    config=$(nginx -T 2>/dev/null)

    ciphers=$(echo "$config" | \
        grep -Poi '^\h*ssl_ciphers\h+\K[^;]+' | head -n1)

    proxy_ciphers=$(echo "$config" | \
        grep -Poi '^\h*proxy_ssl_ciphers\h+\K[^;]+' | head -n1)

    if [ -z "$ciphers" ]; then
        fail "ssl_ciphers directive missing"
        return
    fi

    # Check that PFS families are present
    if ! echo "$ciphers" | grep -Eiq 'ECDHE|EECDH|DHE|EDH'; then
        fail "No forward secrecy ciphers detected in ssl_ciphers"
        return
    fi

    # Fail if obvious weak patterns detected
    if echo "$ciphers" | grep -Eiq 'NULL|RC4|MD5|DES|3DES|EXP|aNULL'; then
        fail "Weak cipher patterns detected in ssl_ciphers"
        return
    fi

    # Optional proxy check (if configured)
    if [ -n "$proxy_ciphers" ]; then
        if ! echo "$proxy_ciphers" | grep -Eiq 'ECDHE|EECDH|DHE|EDH'; then
            fail "No forward secrecy ciphers detected in proxy_ssl_ciphers"
            return
        fi

        if echo "$proxy_ciphers" | grep -Eiq 'NULL|RC4|MD5|DES|3DES|EXP|aNULL'; then
            fail "Weak cipher patterns detected in proxy_ssl_ciphers"
            return
        fi
    fi

    pass "Forward secrecy ciphers configured"
}
