#!/bin/bash

check_proxy_hide_headers() {

    # nginx -T is the authoritative source for effective config
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit proxy_hide_header (nginx -T unavailable)"
        return
    fi

    # Check for both required directives
    if nginx -T 2>/dev/null | grep -Pqi '^\h*proxy_hide_header\h+X-Powered-By\s*;' &&
       nginx -T 2>/dev/null | grep -Pqi '^\h*proxy_hide_header\h+Server\s*;' ; then
        pass "proxy_hide_header hides Server and X-Powered-By headers"
    else
        fail "proxy_hide_header missing for Server and/or X-Powered-By"
    fi
}
