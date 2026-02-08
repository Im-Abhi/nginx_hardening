#!/bin/bash

check_branding() {
    if grep -qi nginx /usr/share/nginx/html/index.html 2>/dev/null; then
        fail "Default nginx index page exposes branding"
    else
        pass "nginx index page does not expose branding"
    fi

    if grep -qi nginx /usr/share/nginx/html/50x.html 2>/dev/null; then
        fail "Default nginx error page exposes branding"
    else
        pass "nginx error page does not expose branding"
    fi
}