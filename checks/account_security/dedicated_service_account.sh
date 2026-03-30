#!/usr/bin/env bash

# CIS 2.2.1 - Ensure NGINX runs as a non-privileged dedicated service account
# Automation Level: Automated

check_dedicated_service_account() {
    local config
    local service_user
    local uid
    local sys_uid_max
    local current_shell

    if ! config="$(nginx -T 2>/dev/null)"; then
        echo "nginx configuration dump failed (manual verification required)"
        return 1
    fi

    # -------- Extract Configured User (ignore comments) --------
    service_user="$(
        echo "$config" \
        | grep -Evi '^[[:space:]]*#' \
        | awk '/^[[:space:]]*user[[:space:]]+/{sub(/;/,"",$2); print $2; exit}'
    )"

    if [[ -z "$service_user" ]]; then
        echo "nginx user directive is missing"
        return 1
    fi

    # -------- Ensure OS Account Exists --------
    if ! id "$service_user" >/dev/null 2>&1; then
        echo "OS account '$service_user' does not exist"
        return 1
    fi

    # -------- Ensure System Account (UID below SYS_UID_MAX) --------
    uid="$(id -u "$service_user")"
    sys_uid_max="$(awk '/^SYS_UID_MAX/{print $2}' /etc/login.defs 2>/dev/null)"

    if [[ -n "$sys_uid_max" && "$uid" -gt "$sys_uid_max" ]]; then
        echo "'$service_user' is not a system account"
        return 1
    fi

    # -------- Ensure Non-Login Shell --------
    current_shell="$(getent passwd "$service_user" | cut -d: -f7)"

    if [[ "$current_shell" != "/sbin/nologin" && \
          "$current_shell" != "/usr/sbin/nologin" && \
          "$current_shell" != "/bin/false" ]]; then
        echo "user '$service_user' has a login shell ($current_shell)"
        return 1
    fi

    return 0
}

remediate_dedicated_service_account() {
    local nginx_conf="/etc/nginx/nginx.conf"
    local user="nginx"
    local home="/var/cache/nginx"
    local shell="/sbin/nologin"
    local backup

    # -------- Do NOT modify if nginx is already running under target user --------
    if pgrep -u "$user" nginx >/dev/null 2>&1; then
        return 1
    fi

    # -------- Create Dedicated System Account --------
    getent group "$user" >/dev/null 2>&1 || groupadd -r "$user" || return 1

    if ! id "$user" >/dev/null 2>&1; then
        useradd -r -g "$user" -d "$home" -s "$shell" "$user" || return 1
    fi

    mkdir -p "$home" || return 1
    chown "$user:$user" "$home" || return 1

    # -------- Update nginx.conf --------
    [[ -f "$nginx_conf" ]] || return 1

    backup="${nginx_conf}.bak.$(date +%s%N)"
    cp -- "$nginx_conf" "$backup" || return 1

    if grep -Evi '^[[:space:]]*#' "$nginx_conf" | grep -Eqi '^[[:space:]]*user[[:space:]]+'; then
        sed -i -E "s/^([[:space:]]*)user[[:space:]]+[^;]+;/\1user $user;/" "$nginx_conf" || return 1
    else
        sed -i "1i user $user;" "$nginx_conf" || return 1
    fi

    if ! nginx -t >/dev/null 2>&1; then
        mv -- "$backup" "$nginx_conf"
        return 1
    fi

    rm -f -- "$backup"
    return 0
}