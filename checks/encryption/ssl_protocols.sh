#!/bin/bash

check_ssl_protocols() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit ssl_protocols (nginx -T unavailable)"
        return
    fi

    # Extract protocol line
    local protocols
    protocols=$(nginx -T 2>/dev/null | grep -Poi '^\h*ssl_protocols\h+\K[^;]+' | head -n1)

    if [ -z "$protocols" ]; then
        fail "ssl_protocols directive missing"
        return
    fi

    # Fail if insecure protocols found
    if echo "$protocols" | grep -Eq 'TLSv1(\.1)?|SSLv'; then
        fail "Insecure TLS protocols enabled: $protocols"
    else
        pass "Only secure TLS protocols enabled: $protocols"
    fi
}
