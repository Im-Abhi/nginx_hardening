#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load shared helpers
source "$BASE_DIR/lib/common.sh"

# Load checks
source "$BASE_DIR/checks/minimize_modules/autoindex.sh"

for file in "$BASE_DIR/checks/account_security/"*; do
    source "$file"
done

for file in "$BASE_DIR/checks/information_disclosure/"*; do
    source "$file"
done

echo "Running nginx security audit..."
echo "--------------------------------"

# minimize modules
check_autoindex

# account security
check_dedicated_service_account
check_nginx_user_locked
check_invalid_shell

# information disclosure
check_server_tokens
check_branding
check_hidden_files_disabled
check_proxy_hide_headers

echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
