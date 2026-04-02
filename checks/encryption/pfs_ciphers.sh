#!/usr/bin/env bash

# CIS 4.1.14 – Ensure only Perfect Forward Secrecy Ciphers are Leveraged
# Automation Level: Manual (Requires organizational policy review)

check_pfs_ciphers() {

    command -v nginx >/dev/null 2>&1 || {
        echo "nginx binary not found"
        return 1
    }

    local errors=""
    local has_ssl=0
    local has_proxy_pass=0
    local has_proxy_ssl=0

    # 1. Parse configuration in a single pass
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

        # 2. Check for presence of PFS cipher families OR modern TLS 1.3 ciphers
        if ! grep -Eqi 'ECDHE|EECDH|DHE|EDH|TLS_AES_|TLS_CHACHA20' <<< "$val"; then
            errors+="  - $type in $file (line $line) does not contain PFS or TLS 1.3 cipher families.\n"
        fi

        # 3. Safely tokenize and check for explicit weak/non-PFS inclusions
        local has_weak=0
        local weak_list=""
        
        # Normalize any accidental spaces to colons, then use safe array splitting
        local normalized_val="${val// /:}"
        IFS=':' read -ra cipher_list <<< "$normalized_val"

        for cipher in "${cipher_list[@]}"; do
            [[ -z "$cipher" ]] && continue
            
            # Ignore explicit exclusions (any string starting with '!')
            if [[ "$cipher" != !* ]]; then
                # Use bounded POSIX regex to prevent substring false positives
                if [[ "$cipher" =~ (^|[-_:])(RC4|MD5|DES|3DES|EXP|NULL|aNULL|IDEA)($|[-_:]) ]]; then
                    has_weak=1
                    weak_list="$weak_list $cipher"
                fi
            fi
        done

        if [[ "$has_weak" -eq 1 ]]; then
            errors+="  - $type in $file (line $line) explicitly enables weak/non-PFS ciphers:$weak_list\n"
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
            gsub(/["\047]/, "", val) # Strips both single and double quotes
            print file, line, type, val
        }
    ')

    # 4. Evaluate missing global directives
    if [[ "$has_ssl" -eq 0 ]]; then
        errors+="  - 'ssl_ciphers' directive is missing (NGINX defaults may not guarantee PFS).\\n"
    fi

    if [[ "$has_proxy_pass" -eq 1 && "$has_proxy_ssl" -eq 0 ]]; then
        errors+="  - NGINX acts as a proxy (proxy_pass found) but 'proxy_ssl_ciphers' is missing.\\n"
    fi

    # 5. Output raw errors and guidance
    if [[ -n "$errors" ]]; then
        errors="MANUAL: ${errors}"
        errors+="\n  Remediation Guidance:\n"
        errors+="  - Ensure your ciphersuites prioritize Perfect Forward Secrecy (ECDHE/DHE/TLS1.3) and exclude weak ciphers.\n"
        errors+="  - Example configuration:\n"
        errors+="      ssl_ciphers EECDH:EDH:!NULL:!SSLv2:!RC4:!aNULL:!3DES:!IDEA;\n"
        
        if [[ "$has_proxy_pass" -eq 1 ]]; then
            errors+="      proxy_ssl_ciphers EECDH:EDH:!NULL:!SSLv2:!RC4:!aNULL:!3DES:!IDEA;\n"
        fi
        
        echo -e "${errors%\\n}"
    fi
}

remediate_pfs_ciphers() {

    # This control intentionally requires manual remediation.
    # Automatically modifying cipher suites may break compatibility
    # with legacy clients, APIs, or upstream proxy services.
    
    return 1
}