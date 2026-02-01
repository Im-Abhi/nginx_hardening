#!/bin/bash

check_invalid_shell() { 
    l_output="" l_output2="" l_out="" 
    if [ -f /etc/nginx/nginx.conf ]; then 
        l_user="$(awk '$1~/^\s*user\s*$/ {print $2}' /etc/nginx/nginx.conf | sed -r 's/;.*//g')" 
        l_valid_shells="^($( sed -rn '/^\//{s,/,\\\\/,g;p}' /etc/shells | paste -s -d '|' - ))$" 
        l_out="$(awk -v pat="$l_valid_shells" -v ngusr="$l_user" -F: '($(NF) ~ pat && $1==ngusr) { $(NF-1) }' /etc/passwd)" 
        if [ -z "$l_out" ]; then 
            l_output="nginx user account: \"$l_user\" has an invalid shell" 
        else 
            l_output2="nginx user account: \"$l_user\" has a valid shell: \"$l_out\"" 
        fi 
    else 
        l_output2="nginx user account can not be determined.\n - file: \"/etc/nginx/nginx.conf\" is missing" 
    fi 

    if [ -z "$l_output2" ]; then 
        pass "$l_output" 
    else 
        fail "$l_output2" 
    fi 
} 
