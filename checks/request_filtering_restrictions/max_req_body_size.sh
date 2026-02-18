#!/bin/bash

# CIS X.X.X – Ensure client_max_body_size Is Configured Appropriately
# Verifies:
#   - client_max_body_size is explicitly set.
#   - Value is not excessively large or unlimited.
# Automation Level: Partial
# Notes:
#   - Acceptable value depends on application requirements.
#   - Setting to 0 disables limit (NOT recommended).
# Remediation Example (adjust value per application needs):
#   client_max_body_size 1M;

check_client_max_body_size() {

    if ! nginx -T >/dev/null 2>&1; then
        fail "cannot audit client_max_body_size (nginx -T unavailable)"
        return
    fi

    local config size

    config=$(nginx -T 2>/dev/null)

    size=$(echo "$config" | \
        grep -Poi '^\h*client_max_body_size\h+\K[^;]+' | head -n1)

    if [ -z "$size" ]; then
        fail "client_max_body_size directive not configured"

        # --- Suggested Remediation (NOT auto-applied) ---
        # echo "Add inside http, server, or location block:"
        # echo "client_max_body_size 1M;"
        # ------------------------------------------------

        return
    fi

    # Fail if unlimited
    if [ "$size" = "0" ]; then
        fail "client_max_body_size is unlimited (0)"

        # --- Suggested Remediation ---
        # echo "Set a reasonable limit:"
        # echo "client_max_body_size 1M;"
        # --------------------------------

        return
    fi

    # Optional sanity check for excessively large values (>50M example threshold)
    if echo "$size" | grep -Eiq '([5-9][0-9]|[1-9][0-9]{2,})M|G'; then
        echo "[MANUAL REVIEW REQUIRED]"
        echo "client_max_body_size set to $size (verify this is appropriate)"
        return
    fi

    pass "client_max_body_size configured as $size"
}
