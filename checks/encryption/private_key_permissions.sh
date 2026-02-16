#!/bin/bash

# CIS 4.X.X – Ensure Private Key File Permissions Are 400
# Verifies:
#   - All ssl_certificate_key files configured in nginx have permission 400.
# Automation Level: Automated
# Notes:
#   - Extracts key paths from effective nginx configuration (nginx -T).
#   - Only validates keys actively used by nginx.
# Remediation Example:
#   chmod 400 /path/to/keyfile.key

check_private_key_permissions() {

    # Ensure effective configuration is available
    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit private key permissions (nginx -T unavailable)"
        return
    fi

    local keys non_compliant=0

    # Extract all ssl_certificate_key paths from effective config
    keys=$(nginx -T 2>/dev/null | \
        grep -Poi '^\h*ssl_certificate_key\h+\K[^;]+' | sort -u)

    if [ -z "$keys" ]; then
        fail "No ssl_certificate_key directives found in configuration"
        return
    fi

    while IFS= read -r key; do

        # Remove quotes if present
        key=$(echo "$key" | sed 's/"//g')

        if [ ! -f "$key" ]; then
            fail "Private key file not found: $key"
            non_compliant=1
            continue
        fi

        perm=$(stat -Lc "%a" "$key" 2>/dev/null)

        if [ "$perm" != "400" ]; then
            fail "Private key file $key has insecure permission ($perm, expected 400)"
            non_compliant=1
        fi

    done <<< "$keys"

    if [ "$non_compliant" -eq 0 ]; then
        pass "All configured private key files have permission 400"
    fi
}
