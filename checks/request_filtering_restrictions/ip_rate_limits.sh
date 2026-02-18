#!/bin/bash

# CIS X.X.X – Ensure limit_req Is Configured
# Verifies:
#   - limit_req_zone is configured in http context.
#   - limit_req is configured in server or location context.
# Automation Level: Automated (Prompt-based remediation safe)
# Remediation Example:
#   http {
#       limit_req_zone $binary_remote_addr zone=ratelimit:10m rate=5r/s;
#       server {
#           location / {
#               limit_req zone=ratelimit burst=10 nodelay;
#           }
#       }
#   }

check_limit_req() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit limit_req (nginx -T unavailable)"
        return
    fi

    local config zone limit

    config=$(nginx -T 2>/dev/null)

    zone=$(echo "$config" | \
        grep -Pi '^\h*limit_req_zone\h+\$binary_remote_addr')

    limit=$(echo "$config" | \
        grep -Pi '^\h*limit_req\h+zone=ratelimit')

    if [ -z "$zone" ]; then
        fail "limit_req_zone not configured"
        # suggest_fix_limit_req
        return
    fi

    if [ -z "$limit" ]; then
        fail "limit_req not configured in server/location context"
        # suggest_fix_limit_req
        return
    fi

    pass "Request rate limiting properly configured"
}

suggest_fix_limit_req() {

    echo
    read -p "Would you like to configure request rate limiting? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    read -p "Enter request rate (default 5r/s): " rate
    read -p "Enter burst value (default 10): " burst

    rate=${rate:-5r/s}
    burst=${burst:-10}

    local target_file="/etc/nginx/nginx.conf"

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    # Insert limit_req_zone inside http block
    sed -i "/http\s*{/a \    limit_req_zone \$binary_remote_addr zone=ratelimit:10m rate=${rate};" "$target_file"

    # Insert limit_req inside first location block
    sed -i "/location\s*\/\s*{/a \        limit_req zone=ratelimit burst=${burst} nodelay;" "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}
