#!/bin/bash

# CIS X.X.X – Ensure limit_conn Is Configured
# Verifies:
#   - limit_conn_zone is configured in http context.
#   - limit_conn is configured in server or location context.
# Automation Level: Automated (Prompt-based remediation safe)
# Remediation Example:
#   http {
#       limit_conn_zone $binary_remote_addr zone=limitperip:10m;
#       server {
#           limit_conn limitperip 10;
#       }
#   }

check_limit_conn() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit limit_conn (nginx -T unavailable)"
        return
    fi

    local config zone limit

    config=$(nginx -T 2>/dev/null)

    zone=$(echo "$config" | \
        grep -Pi '^\h*limit_conn_zone\h+\$binary_remote_addr')

    limit=$(echo "$config" | \
        grep -Pi '^\h*limit_conn\h+limitperip\h+[0-9]+')

    if [ -z "$zone" ]; then
        fail "limit_conn_zone not configured"
        # suggest_fix_limit_conn
        return
    fi

    if [ -z "$limit" ]; then
        fail "limit_conn not configured in server context"
        # suggest_fix_limit_conn
        return
    fi

    pass "Connection limiting properly configured"
}

suggest_fix_limit_conn() {

    echo
    read -p "Would you like to configure connection limits? (y/n): " choice
    if [[ "$choice" != "y" ]]; then
        echo "Remediation skipped."
        return
    fi

    read -p "Enter max connections per IP (default 10): " max_conn
    max_conn=${max_conn:-10}

    local target_file="/etc/nginx/nginx.conf"

    echo "Creating backup..."
    cp "$target_file" "$target_file.bak.$(date +%F-%H%M)"

    echo "Applying remediation..."

    # Insert limit_conn_zone inside http block
    sed -i "/http\s*{/a \    limit_conn_zone \$binary_remote_addr zone=limitperip:10m;" "$target_file"

    # Insert limit_conn inside first server block
    sed -i "/server\s*{/a \        limit_conn limitperip ${max_conn};" "$target_file"

    echo "Validating configuration..."
    if nginx -t; then
        echo "Remediation successful."
    else
        echo "Configuration invalid. Restoring backup."
        mv "$target_file.bak."* "$target_file"
    fi
}
