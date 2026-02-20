#!/bin/bash

# CIS X.X.X – Ensure X-Frame-Options Header Is Configured
# Verifies:
#   - add_header X-Frame-Options is configured.
#   - Uses SAMEORIGIN or DENY policy.
# Automation Level: Automated (Prompt-based remediation safe)
# Notes:
#   - Policy should match organizational needs.
#   - SAMEORIGIN is common default.
# Remediation Example:
#   add_header X-Frame-Options "SAMEORIGIN" always;

check_x_frame_options() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit X-Frame-Options (nginx -T unavailable)"
        return
    fi

    local config header

    config=$(nginx -T 2>/dev/null)

    header=$(echo "$config" | \
        grep -Pi '^\h*add_header\h+X-Frame-Options\b')

    if [ -z "$header" ]; then
        fail "X-Frame-Options header not configured"
        # suggest_fix_x_frame_options
        return
    fi

    if ! echo "$header" | grep -Eiq 'SAMEORIGIN|DENY'; then
        fail "X-Frame-Options configured but value may be insecure"
        # suggest_fix_x_frame_options
        return
    fi

    pass "X-Frame-Options properly configured"
}


suggest_fix_x_frame_options() {

    echo
    read -p "Would you like to configure X-Frame-Options? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    echo "Select policy:"
    echo "1) SAMEORIGIN"
    echo "2) DENY"
    read -p "Enter choice (1/2, default 1): " policy_choice

    if [[ "$policy_choice" == "2" ]]; then
        policy="DENY"
    else
        policy="SAMEORIGIN"
    fi

    local target_file="/etc/nginx/nginx.conf"

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    # Insert into first server block
    sed -i "/server\s*{/a \    add_header X-Frame-Options \"${policy}\" always;" "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}