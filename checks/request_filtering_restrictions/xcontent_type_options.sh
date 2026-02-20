#!/bin/bash

# CIS X.X.X – Ensure X-Content-Type-Options Header Is Configured on All Server Blocks
# Verifies:
#   - Each server block contains:
#       add_header X-Content-Type-Options "nosniff" always;
# Automation Level: Automated (Prompt-based remediation safe)
# Notes:
#   - Must exist in every server block.
#   - 'always' flag is required.
# Remediation Example:
#   add_header X-Content-Type-Options "nosniff" always;

check_x_content_type_options() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit X-Content-Type-Options (nginx -T unavailable)"
        return
    fi

    local config server_count compliant_count

    config=$(nginx -T 2>/dev/null)

    # Count server blocks
    server_count=$(echo "$config" | grep -c '^\h*server\s*{')

    # Count server blocks containing correct header
    compliant_count=$(echo "$config" | \
        awk '
        BEGIN { in_server=0; has_header=0; total=0 }
        /^\s*server\s*{/ { in_server=1; has_header=0 }
        in_server && /add_header\s+X-Content-Type-Options\s+"nosniff"\s+always;/ { has_header=1 }
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
        fail "X-Content-Type-Options not configured on all server blocks"
        # suggest_fix_x_content_type_options
        return
    fi

    pass "X-Content-Type-Options configured on all server blocks"
}

suggest_fix_x_content_type_options() {

    echo
    read -p "Would you like to add X-Content-Type-Options to all server blocks? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    local target_file="/etc/nginx/nginx.conf"

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    # Insert header into every server block
    sed -i '/server\s*{/a \    add_header X-Content-Type-Options "nosniff" always;' "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}