#!/usr/bin/env bash

# CIS 2.2.2 - Ensure the NGINX service account is locked
# Automation Level: Automated

check_service_account_locked() {
    local config
    local service_user

    # -------- Prerequisite --------
    if ! config="$(nginx -T 2>/dev/null)"; then
        manual "2.2.2 service account lock check (nginx configuration dump failed)"
        return
    fi

    # -------- Extract nginx service user --------
    service_user=$(echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}')

    if [[ -z "$service_user" ]]; then
        handle_failure "2.2.2 nginx user directive missing" remediate_service_account_locked
        return
    fi

    if ! id "$service_user" >/dev/null 2>&1; then
        handle_failure "2.2.2 OS account '$service_user' does not exist" remediate_service_account_locked
        return
    fi

    # -------- Check if account is locked --------
    local shadow_status
    shadow_status=$(passwd -S "$service_user" 2>/dev/null | awk '{print $2}')

    if [[ "$shadow_status" == "L" ]]; then
        pass "2.2.2 nginx service account '$service_user' is locked"
        return
    fi

    handle_failure "2.2.2 nginx service account '$service_user' is not locked" remediate_service_account_locked
}

remediate_service_account_locked() {
    local service_user
    local config

    if ! config="$(nginx -T 2>/dev/null)"; then
        return 1
    fi

    service_user=$(echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}')

    if [[ -z "$service_user" ]]; then
        return 1
    fi

    # Do NOT modify if user not present
    if ! id "$service_user" >/dev/null 2>&1; then
        return 1
    fi

    # Lock the account
    passwd -l "$service_user" >/dev/null 2>&1 || return 1

    return 0
}