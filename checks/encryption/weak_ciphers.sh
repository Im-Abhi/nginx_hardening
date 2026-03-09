#!/usr/bin/env bash

# CIS 4.1.5 – Disable weak ciphers
# Automation Level: Manual (Requires organizational policy review)

check_weak_ciphers_disabled() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_ssl=0
    local has_proxy_pass=0
    local has_proxy_ssl=0

    while read -r file line type val; do

        if [[ "$type" == "proxy_pass" ]]; then
            has_proxy_pass=1
            continue
        fi

        if [[ "$type" == "ssl_ciphers" ]]; then
            has_ssl=1
        elif [[ "$type" == "proxy_ssl_ciphers" ]]; then
            has_proxy_ssl=1
        fi

        if grep -qF "ALL" <<< "$val"; then

            local missing=""
            for pattern in "!EXP" "!NULL" "!ADH" "!LOW" "!SSLv2" "!SSLv3" "!MD5" "!RC4"; do
                if ! grep -qF "$pattern" <<< "$val"; then
                    missing="$missing $pattern"
                fi
            done

            if [[ -n "$missing" ]]; then
                errors+="  - $type in $file (line $line) uses 'ALL' but is missing required exclusions:$missing\n"
            fi

        else
            local has_weak=0
            local weak_list=""
            
            for cipher in $(tr ':' ' ' <<< "$val"); do
                if [[ "$cipher" != !* ]]; then
                    if grep -Eqi 'RC4|MD5|NULL|EXP|LOW' <<< "$cipher"; then
                        has_weak=1
                        weak_list="$weak_list $cipher"
                    fi
                fi
            done

            if [[ "$has_weak" -eq 1 ]]; then
                errors+="  - $type in $file (line $line) explicitly enables weak ciphers:$weak_list\n"
            fi
        fi

    done < <(nginx -T 2>/dev/null | awk '
        /^# configuration file/ { file=$4; sub(/:$/,"",file); line=0; next }
        { line++ }
        /^[[:space:]]*#/ { next }

        /^[[:space:]]*proxy_pass[[:space:]]+/ {
            print file, line, "proxy_pass", "N/A"
        }

        /^[[:space:]]*(ssl_ciphers|proxy_ssl_ciphers)[[:space:]]+/ {
            type=$1
            val=$0
            sub(/^[[:space:]]*(ssl_ciphers|proxy_ssl_ciphers)[[:space:]]+/, "", val)
            sub(/;[[:space:]]*$/, "", val)
            print file, line, type, val
        }
    ')

    if [[ "$has_ssl" -eq 0 ]]; then
        errors+="  - 'ssl_ciphers' directive is missing (NGINX defaults may allow weak ciphers).\n"
    fi

    if [[ "$has_proxy_pass" -eq 1 && "$has_proxy_ssl" -eq 0 ]]; then
        errors+="  - NGINX acts as a proxy (proxy_pass found) but 'proxy_ssl_ciphers' is missing.\n"
    fi

    if [[ -n "$errors" ]]; then
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Configure cipher suites to meet your organizational security policy.\n"
        errors+="  - Example strong web server configuration (SSL Labs recommended):\n"
        errors+="      ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;\n"

        if [[ "$has_proxy_pass" -eq 1 ]]; then
            errors+="  - Example strong proxy configuration:\n"
            errors+="      proxy_ssl_ciphers ALL:!EXP:!NULL:!ADH:!LOW:!SSLv2:!SSLv3:!MD5:!RC4;\n"
        fi

        echo -e "${errors%\\n}"
    fi
}

remediate_weak_ciphers_disabled() {

    # This control intentionally requires manual remediation.
    # Automatically modifying cipher suites may break compatibility
    # with legacy clients, APIs, or upstream proxy services.

    return 1
}