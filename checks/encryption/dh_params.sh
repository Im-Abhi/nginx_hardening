#!/bin/bash

check_ssl_dhparam() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit ssl_dhparam (nginx -T unavailable)"
        return
    fi

    local dhparam
    dhparam=$(nginx -T 2>/dev/null | grep -Poi '^\h*ssl_dhparam\h+\K[^;]+' | head -n1)

    if [ -z "$dhparam" ]; then
        fail "ssl_dhparam directive missing"
        return
    fi

    if [ ! -f "$dhparam" ]; then
        fail "ssl_dhparam file does not exist: $dhparam"
        return
    fi

    bits=$(openssl dhparam -in "$dhparam" -text -noout 2>/dev/null | \
       grep -m1 'DH Parameters:' | grep -o '[0-9]\+')

    if [ -z "$bits" ]; then
        fail "Unable to determine DH parameter size"
        return
    fi

    if [ "$bits" -lt 2048 ]; then
        fail "DH parameters too weak (${bits} bits)"
        return
    fi

    pass "ssl_dhparam configured and file exists: $dhparam"
}
