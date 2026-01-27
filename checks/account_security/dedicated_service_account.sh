#!/bin/bash

check_dedicated_service_account() {
    local nginx_main_conf="/etc/nginx/nginx.conf"
    local user

    # Check if user directive exists
    if ! grep -Pi -- '^\h*user\h+[^;\n\r]+\h*;.*$' "$nginx_main_conf" >/dev/null 2>&1; then
        fail "nginx user directive missing"
        return
    fi

    # Extract nginx user
    user=$(grep -Poi -- '^\h*user\h+\K[^;\n\r]+' "$nginx_main_conf")

    if [ -z "$user" ]; then
        fail "unable to extract nginx user"
        return
    fi

    # Check sudo privileges
    if sudo -n -l -U "$user" 2>/dev/null | grep -qi "not allowed"; then
        # PASS
        :
    else
        fail "nginx user '$user' has sudo privileges"
        return
    fi

    # Check group membership
    if ! groups "$user" | grep -qw nginx; then
        fail "nginx user '$user' is not in nginx group"
        return
    fi

    pass "nginx runs as dedicated non-privileged user '$user'"
}
