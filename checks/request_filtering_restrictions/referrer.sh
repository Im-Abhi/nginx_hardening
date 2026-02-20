#!/bin/bash

# CIS X.X.X – Ensure Referrer-Policy Header Is Configured on All Server Blocks
# Verifies:
#   - Each server block contains add_header Referrer-Policy
# Automation Level: Partial (Prompt-based remediation safe)
# Notes:
#   - Policy value depends on organization requirements.
#   - This check verifies presence only.
# Remediation Example:
#   add_header Referrer-Policy "no-referrer" always;

check_referrer_policy() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit Referrer-Policy (nginx -T unavailable)"
        return
    fi

    local config server_count compliant_count

    config=$(nginx -T 2>/dev/null)

    server_count=$(echo "$config" | grep -c '^\h*server\s*{')

    compliant_count=$(echo "$config" | \
        awk '
        BEGIN { in_server=0; has_header=0; total=0 }
        /^\s*server\s*{/ { in_server=1; has_header=0 }
        in_server && /add_header\s+Referrer-Policy/ { has_header=1 }
        in_server && /^\s*}/ {
            if (has_header) total++
            in_server=0
        }
        END { print total }
        ')

    if [ "$server_count" -eq 0 ]; then
        fail "No server blocks detected"
        return
    fi

    if [ "$compliant_count" -ne "$server_count" ]; then
        fail "Referrer-Policy not configured on all server blocks"
        # suggest_fix_referrer_policy
        return
    fi

    pass "Referrer-Policy configured on all server blocks"
}

suggest_fix_referrer_policy() {

    echo
    read -p "Would you like to configure Referrer-Policy? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    echo "Select policy:"
    echo "1) no-referrer"
    echo "2) strict-origin"
    echo "3) strict-origin-when-cross-origin (recommended modern default)"
    read -p "Enter choice (1/2/3, default 3): " policy_choice

    case "$policy_choice" in
        1) policy="no-referrer" ;;
        2) policy="strict-origin" ;;
        *) policy="strict-origin-when-cross-origin" ;;
    esac

    local target_file="/etc/nginx/nginx.conf"

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    sed -i "/server\s*{/a \    add_header Referrer-Policy \"${policy}\" always;" "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}