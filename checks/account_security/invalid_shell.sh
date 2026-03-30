#!/usr/bin/env bash

# CIS 2.2.3 - Ensure the NGINX service account has a non-login shell
# Automation Level: Automated

check_invalid_shell() {
    local config
    local service_user
    local user_shell

    if ! config="$(nginx -T 2>/dev/null)"; then
        echo "nginx configuration dump failed (manual verification required)"
        return 1
    fi

    # -------- Extract nginx service user (ignore comments) --------
    service_user="$(
        echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}'
    )"

    if [[ -z "$service_user" ]]; then
        echo "nginx user directive is missing"
        return 1
    fi

    if ! id "$service_user" >/dev/null 2>&1; then
        echo "OS account '$service_user' does not exist"
        return 1
    fi

    # -------- Get current shell --------
    user_shell="$(getent passwd "$service_user" | cut -d: -f7)"

    if [[ -z "$user_shell" ]]; then
        return 0
    fi

    # -------- Enforce explicit non-login shells --------
    case "$user_shell" in
        "/sbin/nologin"|"/usr/sbin/nologin"|"/bin/false")
            return 0
            ;;
        *)
            echo "nginx service account '$service_user' has a login shell ('$user_shell')"
            return 1
            ;;
    esac
}

remediate_invalid_shell() {
    local config
    local service_user
    local new_shell="/sbin/nologin"

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

    # Do NOT modify if user has running processes
    if pgrep -u "$service_user" >/dev/null 2>&1; then
        return 1
    fi

    usermod -s "$new_shell" "$service_user" >/dev/null 2>&1 || return 1

    return 0
}