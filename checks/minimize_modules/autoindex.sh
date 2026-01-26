#!/bin/bash

check_autoindex() {
    local nginx_dir="/etc/nginx"
    local main_conf="$nginx_dir/nginx.conf"
    local conf_dir="$nginx_dir/conf.d"

    # Check main nginx.conf
    if egrep -i "^\s*autoindex\s+on" "$main_conf" 2>/dev/null | grep -q .; then
        fail "autoindex is ENABLED in nginx.conf"
        return
    fi

    # Check conf.d/*.conf if directory exists and has files
    if [ -d "$conf_dir" ] && ls "$conf_dir"/*.conf > /dev/null 2>&1; then
        if egrep -i "^\s*autoindex\s+on" "$conf_dir"/*.conf \
            2>/dev/null | grep -q .; then
            fail "autoindex is ENABLED in conf.d configs"
            return
        fi
    fi

    pass "autoindex is disabled"
}
