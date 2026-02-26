#!/bin/bash

# CIS 3.4 – Ensure log files are rotated
# Verifies:
#   - Log rotation is set to 'weekly'
#   - Log retention is set to 'rotate 13' (approx. 3 months)
# Automation Level: Automated

check_log_rotation() {
    local target_file="/etc/logrotate.d/nginx"

    if [[ ! -f "$target_file" ]]; then
        fail "Nginx logrotate configuration not found at $target_file"
        return
    fi

    local is_weekly=0
    local is_rotate_13=0

    if grep -Eq '^[[:space:]]*weekly\b' "$target_file"; then
        is_weekly=1
    fi

    if grep -Eq '^[[:space:]]*rotate[[:space:]]+13\b' "$target_file"; then
        is_rotate_13=1
    fi

    if [[ "$is_weekly" -eq 1 && "$is_rotate_13" -eq 1 ]]; then
        pass "Log files are rotated weekly and kept for 13 weeks"
        return
    fi

    remediate_log_rotation
}

remediate_log_rotation() {
    local target_file="/etc/logrotate.d/nginx"
    local backup_file="${target_file}.bak.$(date +%s%N)"

    if [[ ! -f "$target_file" ]]; then
        fail "Nginx logrotate config missing, cannot remediate."
        return
    fi

    cp "$target_file" "$backup_file" || { fail "backup failed"; return; }

    # Replace 'daily', 'monthly', or 'yearly' with 'weekly'
    sed -i -E 's/^[[:space:]]*(daily|monthly|yearly)\b/\tweekly/' "$target_file"

    # Replace 'rotate <any_number>' with 'rotate 13'
    if grep -Eq '^[[:space:]]*rotate[[:space:]]+[0-9]+' "$target_file"; then
        sed -i -E 's/^[[:space:]]*rotate[[:space:]]+[0-9]+/\trotate 13/' "$target_file"
    else
        # If the 'rotate' directive is completely missing, inject it right after 'weekly'
        sed -i -E '/^[[:space:]]*weekly\b/a \trotate 13' "$target_file"
    fi

    # Verify the remediation was successful
    local is_weekly=0
    local is_rotate_13=0

    if grep -Eq '^[[:space:]]*weekly\b' "$target_file"; then
        is_weekly=1
    fi

    if grep -Eq '^[[:space:]]*rotate[[:space:]]+13\b' "$target_file"; then
        is_rotate_13=1
    fi

    if [[ "$is_weekly" -eq 1 && "$is_rotate_13" -eq 1 ]]; then
        rm -f "$backup_file"
        pass "Log rotation remediated to weekly and 13 weeks"
    else
        mv "$backup_file" "$target_file"
        fail "Log rotation remediation failed"
    fi
}