#!/bin/bash

# CIS X.X.X – Ensure large_client_header_buffers Is Set to 2 1k
# Verifies:
#   - Directive exists.
#   - Values are exactly: 2 1k
# Automation Level: Automated (Prompt-based remediation safe)
# Remediation Example:
#   large_client_header_buffers 2 1k;

check_large_client_header_buffers() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit large_client_header_buffers (nginx -T unavailable)"
        return
    fi

    local config current expected="2 1k"

    config=$(nginx -T 2>/dev/null)

    current=$(echo "$config" | \
        grep -Poi '^\h*large_client_header_buffers\h+\K[^;]+' | head -n1)

    if [ -z "$current" ]; then
        fail "large_client_header_buffers directive missing"
        # suggest_fix_large_client_header_buffers
        return
    fi

    if [ "$current" != "$expected" ]; then
        fail "large_client_header_buffers set to '$current' (expected '$expected')"
        # suggest_fix_large_client_header_buffers
        return
    fi

    pass "large_client_header_buffers properly configured ($current)"
}


suggest_fix_large_client_header_buffers() {

    echo
    read -p "Would you like to set large_client_header_buffers to '2 1k'? (y/n): " choice

    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    read -p "Enter desired buffer count (default 2): " count
    read -p "Enter desired buffer size (default 1k): " size

    count=${count:-2}
    size=${size:-1k}

    local target_file="/etc/nginx/nginx.conf"

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    # Remove existing directive
    sed -i '/large_client_header_buffers/d' "$target_file"

    # Insert into http block
    sed -i "/http\s*{/a \    large_client_header_buffers ${count} ${size};" "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}
