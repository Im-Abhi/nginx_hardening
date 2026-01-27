#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load shared helpers
source "$BASE_DIR/lib/common.sh"

# Load checks
source "$BASE_DIR/checks/minimize_modules/autoindex.sh"
source "$BASE_DIR/checks/account_security/dedicated_service_account.sh"

echo "Running nginx security audit..."
echo "--------------------------------"

check_autoindex
check_dedicated_service_account

echo "--------------------------------"
echo "Summary: PASS=$PASS FAIL=$FAIL"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
