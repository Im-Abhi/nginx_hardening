#!/bin/bash

# Check nginx service account is locked
check_nginx_user_locked() {
    local nginx_conf="/etc/nginx/nginx.conf"
    local user status

    user=$(grep -Poi -- '^\h*user\h+\K[^;\n\r]+' "$nginx_conf" 2>/dev/null)

    if [ -z "$user" ]; then
        fail "nginx user directive missing"
        return
    fi

    # Run passwd status via sudo
    status=$(sudo -n passwd -S "$user" 2>/dev/null | awk '{print $2}')

    if [ -z "$status" ]; then
        fail "unable to determine password status for nginx user '$user'"
        return
    fi

    if [ "$status" = "L" ] || ["$status" = "LK" ]; then
        pass "nginx service account '$user' is locked"
    else
        fail "nginx service account '$user' is NOT locked (status=$status)"
    fi
}
