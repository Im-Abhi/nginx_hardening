#!/bin/bash

# CIS X.X.X – Ensure Content-Security-Policy Header Is Configured on All Server Blocks
# Verifies:
#   - Each server block contains:
#       add_header Content-Security-Policy "... default-src 'self' ..." always;
# Automation Level: Partial (Prompt-based remediation safe)
# Notes:
#   - CSP policies are application-specific.
#   - This only checks for presence of default-src 'self'.
#   - Custom CSP values are allowed if they include default-src.
# Remediation Example:
#   add_header Content-Security-Policy "default-src 'self'" always;

check_content_security_policy() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit Content-Security-Policy (nginx -T unavailable)"
        return
    fi

    local config server_count compliant_count

    config=$(nginx -T 2>/dev/null)

    server_count=$(echo "$config" | grep -c '^\h*server\s*{')

    compliant_count=$(echo "$config" | \
        awk '
        BEGIN { in_server=0; has_csp=0; total=0 }
        /^\s*server\s*{/ { in_server=1; has_csp=0 }
        in_server && /add_header\s+Content-Security-Policy/ &&
        /default-src/ && /always;/ { has_csp=1 }
        in_server && /^\s*}/ {
            if (has_csp) total++
            in_server=0
        }
        END { print total }
        ')

    if [ "$server_count" -eq 0 ]; then
        fail "No server blocks detected"
        return
    fi

    if [ "$compliant_count" -ne "$server_count" ]; then
        fail "Content-Security-Policy not configured on all server blocks"
        # suggest_fix_content_security_policy
        return
    fi

    pass "Content-Security-Policy configured on all server blocks"
}

suggest_fix_content_security_policy() {

    echo
    read -p "Would you like to add a default CSP (default-src 'self') to all server blocks? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    local target_file="/etc/nginx/nginx.conf"

    echo "WARNING: CSP can break applications if external resources are used."
    read -p "Proceed? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Remediation cancelled."
        return
    fi

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    sed -i "/server\s*{/a \    add_header Content-Security-Policy \"default-src 'self'\" always;" "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}