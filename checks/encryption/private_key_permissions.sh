#!/usr/bin/env bash

# CIS 4.1.3 – Ensure private key permissions are restricted
# Automation Level: Automated

check_private_key_permissions() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local keys=()

    # Extract private keys dynamically from effective configuration
    while read -r key; do
        [[ -n "$key" ]] && keys+=("$key")
    done < <(nginx -T 2>/dev/null | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*ssl_certificate_key[[:space:]]+/ {
            sub(/^[[:space:]]*ssl_certificate_key[[:space:]]+/, "")
            sub(/;[[:space:]]*$/, "")
            gsub(/["\047]/, "")
            print $0
        }
    ' | sort -u)

    # No configured keys means no violation of this specific control
    if [[ ${#keys[@]} -eq 0 ]]; then
        return 0
    fi

    local key
    for key in "${keys[@]}"; do

        if [[ ! -f "$key" ]]; then
            errors+="  - Configured private key file not found on disk: $key\n"
            continue
        fi

        local perm
        # -L flag follows symlinks (crucial for Let's Encrypt certs)
        # Combines GNU stat (-c) with BSD stat (-f) for universal compatibility
        perm=$(stat -Lc "%a" "$key" 2>/dev/null || stat -Lf "%Lp" "$key")

        if [[ "$perm" != "400" ]]; then
            errors+="  - Private key $key has insecure permissions ($perm). Expected: 400\n"
        fi
    done

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Run the following command to restrict permissions on your private keys:\n"
        errors+="      chmod 400 /path/to/your/keyfile.key"

        echo -e "${errors%\\n}"
    fi
}

remediate_private_key_permissions() {

    command -v nginx >/dev/null 2>&1 || return 1

    local keys=()

    while read -r key; do
        [[ -n "$key" ]] && keys+=("$key")
    done < <(nginx -T 2>/dev/null | awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*ssl_certificate_key[[:space:]]+/ {
            sub(/^[[:space:]]*ssl_certificate_key[[:space:]]+/, "")
            sub(/;[[:space:]]*$/, "")
            gsub(/["\047]/, "")
            print $0
        }
    ' | sort -u)

    local key
    for key in "${keys[@]}"; do

        [[ -f "$key" ]] || continue

        local perm
        perm=$(stat -Lc "%a" "$key" 2>/dev/null || stat -Lf "%Lp" "$key")

        if [[ "$perm" != "400" ]]; then
            # Standard chmod automatically follows symlinks and modifies the target
            chmod 400 "$key" || return 1
        fi
    done

    return 0
}