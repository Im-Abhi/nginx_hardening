#!/bin/bash

check_http_to_https_redirect() {

    # nginx -T is required to inspect effective configuration
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit HTTP to HTTPS redirect (nginx -T unavailable)"
        return
    fi

    # Check for a server block listening on port 80 that redirects to HTTPS
    if nginx -T 2>/dev/null | grep -Pziq \
'server\s*\{[^}]*listen\s+80[^;]*;[^}]*return\s+301\s+https://'; then
        pass "HTTP requests are redirected to HTTPS"
    else
        fail "no HTTP to HTTPS redirect found for port 80 listeners"
    fi
}
