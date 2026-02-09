#!/bin/bash

check_ssl_certificate_configured() {

    # nginx -T is required for authoritative inspection
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit SSL certificate configuration (nginx -T unavailable)"
        return
    fi

    local cert key

    # Extract certificate and key paths from effective config
    cert=$(nginx -T 2>/dev/null | grep -Poi '^\h*ssl_certificate\h+\K[^;]+' | head -n1)
    key=$(nginx -T 2>/dev/null | grep -Poi '^\h*ssl_certificate_key\h+\K[^;]+' | head -n1)

    # Check directives exist
    if [ -z "$cert" ] || [ -z "$key" ]; then
        fail "SSL certificate and/or key directive missing"
        return
    fi

    # Check files exist
    if [ ! -f "$cert" ]; then
        fail "SSL certificate file does not exist: $cert"
        return
    fi

    if [ ! -f "$key" ]; then
        fail "SSL certificate key file does not exist: $key"
        return
    fi

    pass "SSL certificate and key are configured and files exist"
}
