#!/bin/bash

check_ocsp_stapling() {

    # Ensure we can inspect effective config
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit OCSP stapling (nginx -T unavailable)"
        return
    fi

    local stapling verify

    # Extract stapling settings
    stapling=$(nginx -T 2>/dev/null | grep -Pi '^\h*ssl_stapling\h+on\b')
    verify=$(nginx -T 2>/dev/null | grep -Pi '^\h*ssl_stapling_verify\h+on\b')

    if [ -z "$stapling" ]; then
        fail "OCSP stapling is not enabled (ssl_stapling on; missing)"
        return
    fi

    if [ -z "$verify" ]; then
        echo "[WARNING] ssl_stapling enabled but ssl_stapling_verify not enabled"
        pass "OCSP stapling enabled (verification not explicitly configured)"
        return
    fi

    pass "OCSP stapling and verification enabled"
}
