#!/bin/bash

check_server_tokens() {
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot determine effective nginx config (nginx -T unavailable)"
        return
    fi

    if nginx -T 2>/dev/null | grep -Pqi '^\h*server_tokens\h+off\b'; then
        pass "server_tokens explicitly disabled"
    else
        fail "server_tokens not explicitly disabled (default is on)"
    fi
}
