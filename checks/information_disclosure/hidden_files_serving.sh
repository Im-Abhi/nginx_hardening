#!/bin/bash

check_hidden_files_disabled() {

    if nginx -T 2>/dev/null | grep -Pziq \
    'location\h+~\h*/\\\.\S*\h*\{[^}]*deny\h+all;' ; then
        pass "Hidden files access is denied"
    else
        fail "Hidden files are not explicitly denied"
    fi
}
