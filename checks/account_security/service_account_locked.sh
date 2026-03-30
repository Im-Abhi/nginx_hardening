#!/usr/bin/env bash

# CIS 2.2.2 - Ensure the NGINX service account is locked
# Automation Level: Automated

check_service_account_locked() {
    local config
    local service_user
    local shadow_status

    if ! config="$(nginx -T 2>/dev/null)"; then
        echo "nginx configuration dump failed (manual verification required)"
        return 1
    fi

    # -------- Extract nginx service user --------
    service_user="$(
        echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}'
    )"

    if [[ -z "$service_user" ]]; then
        echo "nginx user directive missing"
        return 1
    fi

    if ! id "$service_user" >/dev/null 2>&1; then
        echo "OS account '$service_user' does not exist"
        return 1
    fi

    # -------- Check if account is locked --------
    shadow_status="$(passwd -S "$service_user" 2>/dev/null | awk '{print $2}')"

    if [[ "$shadow_status" == "L" ]]; then
        return 0
    fi

    echo "nginx service account '$service_user' is not locked"
    return 1
}

remediate_service_account_locked() {
    local config
    local service_user

    if ! config="$(nginx -T 2>/dev/null)"; then
        return 1
    fi

    service_user="$(
        echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}'
    )"

    if [[ -z "$service_user" ]]; then
        return 1
    fi

    if ! id "$service_user" >/dev/null 2>&1; then
        return 1
    fi

    # Lock the account
    passwd -l "$service_user" >/dev/null 2>&1 || return 1

    return 0
}